using System.Threading.Tasks;
using Dapr.Client;

namespace api.Services
{
    public class DaprStateProfileRepository : IProfileRepository
    {
        private const string DAPR_STORE_NAME = "statestore";
        
        public async Task<Profile> Get(int id)
        {  
            using var client = new DaprClientBuilder().Build();
            Profile profile = null;
            profile = await client.GetStateAsync<Profile>(DAPR_STORE_NAME, id.ToString());
            return profile;
        }

        public async Task<Profile> Put(int id, Profile profile)
        {
            profile.Id = id;
            using var client = new DaprClientBuilder().Build();
            await client.SaveStateAsync<Profile>(DAPR_STORE_NAME, id.ToString(), profile);
            return profile;
        }
    }
}