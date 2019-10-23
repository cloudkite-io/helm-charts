env=$1
cloud=$2

# exit when any command fails
set -e

usageErrorMessage="Usage ./deploy.sh <dev|stage|prod> <aws|gcp>"
if [[ "$env" != "dev" && $env != "stage" && $env != "prod" ]]; then
        echo $usageErrorMessage
        exit
fi
if [[ "$cloud" != "aws" && $cloud != "gcp" ]]; then
        echo $usageErrorMessage
        exit
fi

echo "Generating dry-run"
helm template --debug --namespace pritunl \
        --values values.yaml --values $cloud.values.yaml --values $env.values.yaml --values $env.secrets.yaml .

echo "Do you want to perform these actions?
Helm will perform the actions described above.
Only 'yes' will be accepted to approve."
read -p "Enter a value: " shouldContinue

if [[ "$shouldContinue" != "yes" ]]; then
        echo "You have canceled the upgrade"
        exit
fi

helm upgrade --install --debug --atomic --cleanup-on-fail --wait \
        --namespace pritunl \
        --values values.yaml --values $cloud.values.yaml --values $env.values.yaml --values $env.secrets.yaml \
        --timeout 3000 pritunl .
