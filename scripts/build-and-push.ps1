param
(
    $registryName,
    $repositoryName,
    $tagName,
    $buildContextPath
)

function build($imageName)
{
    docker image build -t $imageName $buildContextPath
    docker image push $imageName
}

az acr login -n $registryName
build -imageName "$registryName.azurecr.io/$($repositoryName):$tagName"
build -imageName "$registryName.azurecr.io/$($repositoryName):latest"
