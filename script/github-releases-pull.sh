#!/bin/bash
# Bash script to sync releases of a particular GitHub repository.
# WILL NOT DOWNLOAD SOURCE TAR BALLS
# WILL NOT PRUNE ALREADY DOWNLOADED RELEASES WHICH LATER GET DELETED IN REPO
#
# Author: Jinrui Wang <wangjr@shanghaitech.edu.cn>

# TODO: Prune removed releases
# TODO: Provide switch whether fetch pre-releases
# TODO: Provide switch whether fetch source tar balls

fetch_page_content() {
	cat $1 | grep "https://github.com/$2/releases/download/[^\"]+"  -oP | xargs -n1 -t wget -nc
}

usage() {
	echo "$0: Invalid argument(s)"
	echo "Usage: $0 <owner/repo> <target> [locked]"
	echo "Bash script to sync releases of a particular GitHub repository."
	echo 
	echo "ARGUMENTS:"
	echo "    <owner/repo>      A string to indicate which repo to pull." 
	echo "    <target>          The path to store the downloaded files locally." 
	echo "    [locked]          Passing in anything indicate the lock is acquired." 
	echo "                      Normally only used by the script itself."
	echo
	echo "NOTICE:"
	echo "    1. I would strongly oppose any action to parallelize the download, to prevent flooding GitHub servers, even if this is extremely unlikely."
	echo "    2. WILL NOT DOWNLOAD SOURCE TAR BALLS."
	echo "    3. WILL NOT PRUNE ALREADY DOWNLOADED RELEASES WHICH LATER GET DELETED IN REPO."
	echo "    4. WILL FETCH PRE-RELEASES."
	echo 
	echo "AUTHOR"
	echo "    Jinrui Wang <wangjr@shanghaitech.edu.cn>"
	echo 
}

tempfile=$2/.github-releases-pull.${1//\//@}.lock

prepare() {
	mkdir -p $2
	if [ $? -ne 0 ] ; then
		echo "$0: Unable to create directories. Refer to above for error details. Aborting!"
		exit 1
	fi

	touch $tempfile
	if [ $? -ne 0 ] ; then
		echo "$0: Unable to write to lock file. Refer to above for error details. Aborting!"
		exit 1
	fi
}

do_fetch() {
	cd $2

	wget --save-headers https://api.github.com/repos/$1/releases -O $tempfile
	
	if [ $? -ne 0 ] ; then
		echo "$0: Repository not found or GitHub unreachable!"
		exit 1
	fi
	
	fetch_page_content $tempfile $1

	until [ -z `cat $tempfile | grep rel=\"next\"` ] ; do
		cat $tempfile | grep -oP "https://api.github.com/repositories/\\d+/releases\\?page=\\d+(?=>; rel=\"next\")" | xargs curl -o $tempfile -i
		fetch_page_content $tempfile $1
	done
}

if [ $# -eq 2 ] ; then
	prepare $*
	flock -n $tempfile -c "$0 $* true" && rm $tempfile && exit 0
	echo "$0: Lock contention or unknown error. Refer to above for error details. Aborting!"
	exit 1
elif [ $# -eq 3 ] ; then
	do_fetch $*
else 
	usage
	exit 1
fi
