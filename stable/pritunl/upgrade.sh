version=$1

if [[ "$version" == "" ]]; then
        echo "Usage ./upgrade.sh <new-version>"
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

