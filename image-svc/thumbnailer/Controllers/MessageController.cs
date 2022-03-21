using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace thumbnailer.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class MessageController : ControllerBase
    {
        private readonly ILogger<MessageController> _logger;
        private readonly IConfiguration _configuration;

        public MessageController(ILogger<MessageController> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
        }

        private readonly Regex blobUrlRegex = new Regex(@"^https://(?<accountName>[a-z0-9]+)\.blob\.core\.windows\.net/(?<containerName>[a-z0-9-]+)/(?<blobName>.*)$");

        [HttpPost("/grid-queue-message")]
        public async Task Post([FromBody] dynamic messageString)
        {
            dynamic message = JObject.Parse(messageString.ToString());
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

            _logger.LogInformation($"Processing {blobName}");
            var connString = _configuration.GetValue<string>("imageThumbnailsStorageConnectionString");
            var blobContainerClient = new BlobContainerClient(connString, containerName);
            var blobClientDown = blobContainerClient.GetBlobClient(blobName);
            var blobClientUp = blobContainerClient.GetBlobClient(blobName+".thumbnail.png");
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
        }
     }
}
