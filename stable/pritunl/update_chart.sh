#!/bin/bash

# This script upgrades the pritunl helm chart.
# After pushing to github, the chart will be available for use.

# Exit after any error
set -e

version=$(sed -n 's/version: \(.*\)/\1/p' Chart.yaml)

helm template .
echo "Do you want to update the Chart?
Only 'yes' will be accepted to approve."
read -p "Enter a value: " shouldContinue
 
 if [[ "$shouldContinue" != "yes" ]]; then
         echo "You have canceled the update"
         exit
 fi

# Package helm chart
helm package .

# Move to `docs` directory. This tells github pages to host that file
mv "./pritunl-$version.tgz" ../../docs/

# Index the new helm release. This tells helm metadata about the new release.
$(cd ../../docs/; helm repo index .)

# The `index.yaml` in `docs` will now contain info about the new release.

