using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Configuration;

namespace api.Services
{
    public class BlobStoreImageUploader : IImageUploader
    {

        private readonly IConfiguration _configuration;

        public BlobStoreImageUploader(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public string UploadImage(string imagePath, string imageName, string contentType, string bucket, int id, out string[] issues)
        {
            var issueList = new List<string>();
            var connString = _configuration.GetValue<string>("imageUploadStorageConnectionString");
            var blobContainerClient = new BlobContainerClient(connString, bucket);
            blobContainerClient.CreateIfNotExistsAsync().Wait();
            blobContainerClient.SetAccessPolicyAsync(PublicAccessType.Blob).Wait();
            var imageTypeSuffix = "";
            switch (contentType)
            {
                case "image/jpeg":
                    imageTypeSuffix = ".jpg";
                    break;
                case "image/png":
                    imageTypeSuffix = ".png";
                    break;
                case "image/gif":
                    imageTypeSuffix = ".gif";
                    break;
                default:
                    issueList.Add("Unsupported image type.");
                    break;
            }
            var blobName = $"{id}{imageTypeSuffix}";
            var blobClient = blobContainerClient.GetBlobClient(blobName);
            using (FileStream fileStream = File.OpenRead(imagePath))
            {
                blobClient.UploadAsync(fileStream, overwrite: true).Wait();
            }
            issues = issueList.ToArray();
            return blobClient.Uri.ToString();
        }
    }
}
