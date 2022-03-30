#!/usr/bin/env zsh

echo "Git Poll Check All v1.2"

buildconfigs=$( oc get buildconfigs -A -l gitpoller.unstable.tech/type=basic -o json )

jq ".items[]" -c <<< $buildconfigs | while read -r line; do;
  # jq <<< $line
  name=$(jq -r ".metadata.name" <<< $line)
  namespace=$(jq -r '.metadata.namespace' <<< $line)
  gituri=$(jq -r ".spec.source.git.uri" <<< $line)
  gitref=$(jq -r ".spec.source.git.ref // \"main\"" <<< $line)
  echo "$name = $gituri:$gitref"
  ref=$(git ls-remote -h "$gituri" "refs/heads/$gitref" | cut -f1)
  checkref=$(jq -r ".metadata.annotations.\"gitpoller.unstable.tech/lastref\"" <<< $line)
  if [[ "$ref" != "$checkref" ]]; then
    echo "Update needed for $namespace / $name"
    oc start-build -n "$namespace" "$name" -w && oc annotate -n "$namespace" --overwrite buildconfig "$name" "gitpoller.unstable.tech/lastref=$ref"
  else
    echo "$namespace / $name is up to date"
  fi
done

echo done
