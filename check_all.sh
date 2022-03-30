#!/usr/bin/env zsh
buildconfigs=$( oc get buildconfigs -l gitpoller.unstable.tech/type=basic -o json )

jq ".items[]" -c <<< $buildconfigs | while read -r line; do;
  # jq <<< $line
  name=$(jq -r ".metadata.name" <<< $line)
  gituri=$(jq -r ".spec.source.git.uri" <<< $line)
  gitref=$(jq -r ".spec.source.git.ref // \"main\"" <<< $line)
  echo "$name = $gituri:$gitref"
  ref=$(git ls-remote -h "$gituri" "refs/heads/$gitref" | cut -f1)
  checkref=$(jq -r ".metadata.annotations.\"gitpoller.unstable.tech/lastref\"" <<< $line)
  if [[ "$ref" != "$checkref" ]]; then
    echo "Update needed for $name"
    oc start-build "$name" -w && oc annotate --overwrite buildconfig "$name" "gitpoller.unstable.tech/lastref=$ref"
  else
    echo "$name is up to date"
  fi
done

echo done
