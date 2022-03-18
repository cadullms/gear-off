using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using api.Services;
using Dapr.Client;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace api.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class ProfileController : ControllerBase
    {
        private readonly ILogger<ProfileController> _logger;
        private readonly IConfiguration _configuration;
        private readonly IImageUploader _imageUploader;

        private const string DAPR_STORE_NAME = "statestore";

        public ProfileController(ILogger<ProfileController> logger, IConfiguration configuration, IImageUploader imageUploader)
        {
            _logger = logger;
            _configuration = configuration;
            _imageUploader = imageUploader;
        }

        [HttpGet("{id}")]
        public async Task<Profile> Get(int id)
        {
            using var client = new DaprClientBuilder().Build();
            Profile profile = null;
            profile = await client.GetStateAsync<Profile>(DAPR_STORE_NAME, id.ToString());
            return profile;
        }

        [HttpPut("{id}")]
        public async Task<Profile> Put(int id, Profile profile)
        {
            profile.Id = id;
            using var client = new DaprClientBuilder().Build();
            await client.SaveStateAsync<Profile>(DAPR_STORE_NAME, id.ToString(), profile);
            return profile;
        }

        [HttpPut("{id}/image")]
        public IActionResult PutImage(int id, List<IFormFile> files)
        {
            if (files.Count > 1)
            {
                return BadRequest("Only one file supported.");
            }

            if (files.Count == 0)
            {
                return BadRequest("No file provided.");
            }

            var formFile = files.First();
            var filePath = Path.GetTempFileName();
            using (var stream = System.IO.File.Create(filePath))
            {
                formFile.CopyTo(stream);
            }

            string[] issues;
            var imageUrl = _imageUploader.UploadImage(filePath, formFile.FileName, formFile.ContentType, "profile-images", id, out issues);
            if (imageUrl != null)
            {
                _logger.LogInformation($"Successfully processed image {filePath} to {imageUrl}.");
                Profile profile = Get(id).Result;
                if (profile != null)
                {
                    profile.ImageUrl = imageUrl;
                }
                Put(id, profile).Wait();
                return Ok();
            }
            else
            {
                _logger.LogError("Error while processing image {filePath}");
                return BadRequest(issues);
            }
        }
    }
}
