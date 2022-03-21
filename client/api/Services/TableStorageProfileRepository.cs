using System.Text.Json;
using System.Threading.Tasks;
using Azure.Data.Tables;
using Dapr.Client;
using Microsoft.Extensions.Configuration;

namespace api.Services
{
    public class TableStorageProfileRepository : IProfileRepository
    {
        private const string STORAGE_CONNECTION_ENV_VAR = "imageUploadStorageConnectionString";
        private readonly IConfiguration _configuration;

        public TableStorageProfileRepository(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task<Profile> Get(int id)
        {  
            var connectionString = _configuration.GetValue<string>(STORAGE_CONNECTION_ENV_VAR);
            var tableClient = new TableClient(connectionString, "profiles");
            await tableClient.CreateIfNotExistsAsync();
            var profileEntityResponse = await tableClient.GetEntityAsync<TableEntity>("profiles", id.ToString()); 
            if (profileEntityResponse == null)
            {
                return null;
            }

            return JsonSerializer.Deserialize<Profile>((string)profileEntityResponse.Value["value"]);
        }

        public async Task<Profile> Put(int id, Profile profile)
        {
            profile.Id = id;
            var connectionString = _configuration.GetValue<string>(STORAGE_CONNECTION_ENV_VAR);
            var tableClient = new TableClient(connectionString, "profiles");
            await tableClient.CreateIfNotExistsAsync();
            var profileEntity = new TableEntity("profiles",id.ToString());
            profileEntity["value"] = JsonSerializer.Serialize(profile);
            await tableClient.UpsertEntityAsync<TableEntity>(profileEntity); 
            return profile;
        }
    }
}