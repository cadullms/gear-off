using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace ImageService.Thumbnailer
{
    public static class GridQueueMessages
    {
        
        private static string GetEnvironmentVariable(string name)
        {
            return System.Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);
        }

        private static readonly Regex blobUrlRegex = new Regex(@"^https://(?<accountName>[a-z0-9]+)\.blob\.core\.windows\.net/(?<containerName>[a-z0-9-]+)/(?<blobName>.*)$");

        [Function("GridQueueMessages")]
        public async static Task Run([ServiceBusTrigger("image-actions", Connection = "gearoffwasb_SERVICEBUS")] string myQueueItem, FunctionContext context)
        {
            var logger = context.GetLogger("GridQueueMessages");
            dynamic message = JObject.Parse(myQueueItem);
            string source = message.source; // e.g. "/subscriptions/9fe738f4-de59-4073-a7ac-c66fdef4fffa/resourceGroups/gearoff-rg/providers/Microsoft.Storage/storageAccounts/gearoffimg"
            string imgUrl = message.data.url; // e.g. "https://gearoffimg.blob.core.windows.net/profile-images/3.png"
            var imgUrlMatch = blobUrlRegex.Match(imgUrl);
            string accountName = imgUrlMatch.Groups["accountName"].Value;
            string containerName = imgUrlMatch.Groups["containerName"].Value;
            string blobName = imgUrlMatch.Groups["blobName"].Value;
            if (blobName.EndsWith(".thumbnail.png")) //TODO: Filter this already in the event subscription, but keep this as a failsafe to avoid infinite loops
            {
                return;
            }

            logger.LogInformation($"Processing {blobName}");
            var connString = GetEnvironmentVariable("imageThumbnailsStorageConnectionString");
            var blobContainerClient = new BlobContainerClient(connString, containerName);
            var blobClientDown = blobContainerClient.GetBlobClient(blobName);
            var blobClientUp = blobContainerClient.GetBlobClient(blobName + ".thumbnail.png");
            var downloadResult = await blobClientDown.DownloadContentAsync();
            var image = Image.FromStream(downloadResult.Value.Content.ToStream());
            var width = 128;
            var height = 128;
            var resized = new Bitmap(width, height);
            using (var graphics = Graphics.FromImage(resized))
            using (var resizedStream = new MemoryStream())
            {
                graphics.CompositingQuality = CompositingQuality.HighSpeed;
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                graphics.CompositingMode = CompositingMode.SourceCopy;
                graphics.DrawImage(image, 0, 0, width, height);
                resized.Save(resizedStream, ImageFormat.Png);
                resizedStream.Position = 0;
                await blobClientUp.UploadAsync(resizedStream, true);
            }
            logger.LogInformation($"C# ServiceBus queue trigger function processed message: {myQueueItem}");
        }
    }
}





