version=$1

# Exit after any error
set -e

if [[ "$version" == "" ]]; then
        echo "Usage ./upgrade.sh <new-version>"
        exit
fi

helm template .
echo "Do you want to upgrade to this new chart?
Only 'yes' will be accepted to approve."
read -p "Enter a value: " shouldContinue
 
 if [[ "$shouldContinue" != "yes" ]]; then
         echo "You have canceled the upgrade"
         exit
 fi


cat Chart.yaml | sed "s/version.*/version: $version/g" > Chart.temp.yaml
mv Chart.temp.yaml Chart.yaml

# Package helm chart
helm package .

# Move to `docs` directory. This tells github pages to host that file
mv "./pritunl-$version.tgz" ../../docs/

# Index the new helm release. This tells helm metadata about the new release.
$(cd ../../docs/; helm repo index .)

# The `index.yaml` in `docs` will now contain info about the new release.

