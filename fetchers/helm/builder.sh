source "$stdenv/setup"
export HOME=$(pwd)

helm repo add $repoName $repoUrl
mkdir ./temp
helm pull $repoName/$chart --version $version -d ./temp
CHART=$(ls -1 ./temp/*.tgz)
mv $CHART $out
