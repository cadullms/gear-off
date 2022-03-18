using System.Threading.Tasks;

namespace api.Services {
    public interface IImageUploader {
        string UploadImage(string imagePath, string imageName, string contentType, string bucket, int id ,out string[] issues);
    }
}