using System.Threading.Tasks;

namespace api.Services {
    public interface IProfileRepository {
        Task<Profile> Get(int id);
        Task<Profile> Put(int id, Profile profile);
    }
}