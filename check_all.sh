#!/usr/bin/env zsh

echo "Git Poll Check All v1.2"

echo
echo "Checking \"basic\" type projects"
echo

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

echo
echo "Checking \"secure\" type projects"
echo

buildconfigs=$( oc get buildconfigs -A -l gitpoller.unstable.tech/type=secure -o json )

jq ".items[]" -c <<< $buildconfigs | while read -r line; do;
  # jq <<< $line
  name=$(jq -r ".metadata.name" <<< $line)
  namespace=$(jq -r '.metadata.namespace' <<< $line)
  gituri=$(jq -r ".spec.source.git.uri" <<< $line)
  gitref=$(jq -r ".spec.source.git.ref // \"main\"" <<< $line)
  GIT_TOKEN=""
  sourceSecretName=$(jq -r ".spec.source.sourceSecret.name" <<< $line)
  sourceSecret=$(oc get -n "$namespace" secret "$sourceSecretName" -o json)
  # echo $sourceSecret
  sourceSecretType=$(jq -r ".type" <<< $sourceSecret)
  case $sourceSecretType in
    "kubernetes.io/basic-auth")
      GIT_TOKEN=$(jq -r '.data.password' <<< $sourceSecret | base64 -D)
      gitUsername=$(jq -r '.data.username' <<< $sourceSecret)
      if [[ "$gitUsername" != "" ]]; then
        IFS=":" read -r gitProtocol gitUriFragment <<< $gituri
        gituri="$gitProtocol://$gitUsername@${gitUriFragment:2}"
        echo $gituri
      fi
      ;;
    "kubernetes.io/ssh-auth")
      keyfile=$(mktemp)
      jq -r ".data.\"ssh-privatekey\"" <<< $sourceSecret | base64 -D > $keyfile
      ;;
    *)
      echo "UNSUPPORTED buildConfig sourceSecret TYPE"
      ;;
  esac
  echo $GIT_TOKEN
  echo "$name = $gituri:$gitref"
  ref=$(GIT_ASKPASS=$(pwd)/git_askpass.sh GIT_SSH_COMMAND="ssh -i $keyfile -o IdentitiesOnly=yes" GIT_TOKEN="$GIT_TOKEN" git ls-remote -h "$gituri" "refs/heads/$gitref" | cut -f1)
  if [[ -v keyfile && -f $keyfile ]]; then
    rm -f $keyfile #cleanup
  fi
  checkref=$(jq -r ".metadata.annotations.\"gitpoller.unstable.tech/lastref\"" <<< $line)
  if [[ "$ref" != "$checkref" ]]; then
    echo "Update needed for $namespace / $name"
    oc start-build -n "$namespace" "$name" -w && oc annotate -n "$namespace" --overwrite buildconfig "$name" "gitpoller.unstable.tech/lastref=$ref"
  else
    echo "$namespace / $name is up to date"
  fi
done

# echo $buildconfigs

echo done
