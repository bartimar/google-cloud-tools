#!/bin/bash
# Migrate GCE Persistent Disks between Projects

set -eo pipefail
[[ $# < 4 || $# > 5 ]] && echo "USAGE: $0 fromProject toProject diskName fromZone [toZone]" && exit 1
oldProject="$1"
newProject="$2"
diskName="$3"
tmpDisk="${diskName}-tmp"
snapshotName="${diskName}-tmpsnap"
imageName="${diskName}-tmpimage"
oldZone="$4"
newZone="$5"
[[ $newZone == "" ]] && newZone="$oldZone"

echo "Switching to the old project $oldProject"
gcloud config set project "$oldProject" 1>/dev/null

#With creating a snapshot and a disk from that snapshot we avoid having to detach the oldDisk from the running pod
echo "Creating a disk snapshot"
gcloud compute --project "$oldProject" disks snapshot "$diskName"  --zone "$oldZone" --snapshot-names "$snapshotName" 1>/dev/null
echo "Creating a temporary disk from the snapshot"
gcloud compute --project "$oldProject" disks create "$tmpDisk" --zone "$oldZone" --source-snapshot "$snapshotName" --type "pd-standard" 1>/dev/null
echo "Creating a VM image from the temporary disk"
gcloud compute images create "$imageName" --source-disk="$tmpDisk" --source-disk-zone="$oldZone" 1>/dev/null

echo "Getting the image's URL"
imageUrl=$(gcloud compute images list --no-standard-images --uri | grep "$imageName")

echo "Switching to the new project"
gcloud config set project "$newProject" 1>/dev/null

echo "Creating the final disk in the new project"
gcloud compute disks create "$diskName" --image="$imageUrl" --zone="$newZone" 1>/dev/null

echo "Cleaning up"
gcloud config set project "$oldProject" 1>/dev/null
echo Y | gcloud compute snapshots delete "$snapshotName" 1>/dev/null
echo Y | gcloud compute disks delete "$tmpDisk" 1>/dev/null
echo Y | gcloud compute images delete "$imageName" 1>/dev/null
echo "All done"
