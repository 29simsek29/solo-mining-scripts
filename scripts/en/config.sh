#!/bin/bash

config_help()
{
cat << EOF
Usage:
	help			show help information
	show			show configurations
	set			set configurations
EOF
}

config_show()
{
	cat $installdir/.env
}

config_set_all()
{
	local cores
	while true ; do
		read -p "You use several cores to participate in mining: " cores
		expr $cores + 0 &> /dev/null
		if [ $? -eq 0 ] && [ $cores -ge 1 ] && [ $cores -le 32 ]; then
			sed -i "6c CORES=$cores" $installdir/.env
			break
		else
			printf "Please enter an integer greater than 1 and less than 32, and your enter is incorrect, please re-enter!\n"
		fi
	done

	local node_name
	while true ; do
		read -p "Enter your node name(not contain spaces): " node_name
		if [[ $node_name =~ \ |\' ]]; then
			printf "The node name cannot contain spaces, please re-enter!\n"
		else
			sed -i "7c NODE_NAME=$node_name" $installdir/.env
			break
		fi
	done

	local mnemonic=""
	local gas_adress=""
	local balance=""
	while true ; do
		read -p "Enter your gas account mnemonic: " mnemonic
		if [ -z "$mnemonic" ] || [ "$(node $installdir/console.js verify "$mnemonic")" == "Cannot decode the input" ]; then
			printf "Please enter a legal mnemonic, and it cannot be empty!\n"
		else
			gas_adress=$(node $installdir/console.js verify "$mnemonic")
			balance=$(node $installdir/console.js --substrate-ws-endpoint "wss://pc-test.phala.network/khala/ws" free-balance $gas_adress 2>&1)
			balance=$(echo $balance | awk -F " " '{print $NF}')
			balance=$(expr "${balance##*WorkerStat} / 1000000000000"|bc)
			if [ `echo "$balance > 0.1"|bc` -eq 1 ]; then
				sed -i "8c MNEMONIC=$mnemonic" $installdir/.env
				sed -i "9c GAS_ACCOUNT_ADDRESS=$gas_adress" $installdir/.env
				break
			else
				printf "Account PHA is less than 0.1!\n"

			fi
		fi
	done

	local pool_addr=""
	while true ; do
		read -p "Enter your pool address: " pool_addr
		if [ -z "$pool_addr" ] || [ "$(node $installdir/console.js verify "$pool_addr")" == "Cannot decode the input" ]; then
			printf "Please enter a legal pool address, and it cannot be empty!\n"
		else
			sed -i "10c OPERATOR=$pool_addr" $installdir/.env
			break
		fi
	done
}

config()
{
	log_info "----------Test confidenceLevel, waiting for Intel to issue IAS remote certification report!----------"
	local Level=$(phala sgx-test | awk '/confidenceLevel =/{ print $3 }' | tr -cd "[0-9]")
	if [ $(echo "1 <= $Level"|bc) -eq 1 ] && [ $(echo "$Level <= 5"|bc) -eq 1 ]; then
		log_info "----------Your confidenceLevel is：$Level----------"
		case "$1" in
			show)
				config_show
				;;
			set)
				config_set_all
				;;
			*)
				help_config
				break
		esac
	else
		log_info "----------Intel IAS certification has not passed, please check your motherboard or network!----------"
		exit 1
	fi
}
