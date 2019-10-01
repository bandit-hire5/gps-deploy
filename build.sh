#!/usr/bin/env bash
start=$(date +%s.%N)

describeComponent() { 
	cd ..
	cd $1
	echo $1
	git branch
}

case $1 in
list-branches)
	describeComponent "gps-users"
	describeComponent "gps-tracker"
	describeComponent "gps-gateway"
	;;	
all)
	# Update deployment scenarios
	git pull
	# Build the mongo service
	cd ../gps-mongo
	git pull
	./build.sh
	# Build the users service
	cd ../gps-users
	git pull
	./build.sh
	# Build the tracker service
	cd ../gps-tracker
	git pull
	./build.sh
	# Return back to the current folder
	cd ../gps-deploy
	;;
*)
	echo "Usage:"
	echo ""
	echo "# To list all branches for local repositories before the build:"
	echo "./build.sh list-branches"
	echo ""
	echo "# To build all components:"
	echo "./build.sh all"
	echo ""
	;;
esac

dur=$(echo "$(date +%s.%N) - $start" | bc)

LC_NUMERIC="en_US.UTF-8" printf "\n-----Execution time: %.6f seconds-----\n\n" $dur
