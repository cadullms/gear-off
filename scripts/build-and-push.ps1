param
(
    $registryName,
    $repositoryName,
    $tagName,
    $buildContextPath
)

$imageName = "$registryName.azurecr.io/$($repositoryName):$tagName"

az acr login -n $registryName
docker image build -t $imageName $buildContextPath
docker image push $imageName