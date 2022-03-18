using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using api.Services;
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

        public ProfileController(ILogger<ProfileController> logger, IConfiguration configuration, IImageUploader imageUploader)
        {
            _logger = logger;
            _configuration = configuration;
            _imageUploader = imageUploader;
        }

        private static readonly Dictionary<int, Profile> profiles = new Dictionary<int, Profile>();

        [HttpGet("{id}")]
        public Profile Get(int id)
        {
            Profile profile = null;
            profiles.TryGetValue(id, out profile);
            return profile;
        }

        [HttpPut("{id}")]
        public Profile Put(int id, Profile profile)
        {
            profile.Id = id;
            profiles[id] = profile;
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
                Profile profile = null;
                profiles.TryGetValue(id, out profile);
                if (profile != null)
                {
                    profile.ImageUrl = imageUrl;
                }
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
