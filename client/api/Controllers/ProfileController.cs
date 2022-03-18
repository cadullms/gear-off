using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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

        public ProfileController(ILogger<ProfileController> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
        }

        private static readonly Dictionary<int,Profile> profiles = new Dictionary<int, Profile>();

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
            if (!profiles.ContainsKey(id))
            {
                profiles.Add(id, profile);
            }
            else
            {
                profiles[id] = profile;
            }
            
            return profile;
        }
    }
}
