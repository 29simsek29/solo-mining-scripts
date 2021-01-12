#!/bin/bash

install_depenencies()
{
    log_info "----------更新系统源----------"
    apt-get update
    if [ $? -ne 0 ]; then
        log_err "系统源更新失败"
        exit 1
    fi

    log_info "----------安装依赖----------"
    apt-get install -y jq curl
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get install -y docker-ce docker-ce-cli containerd.io
    if [ $? -ne 0 ]; then
        log_err "安装依赖失败"
        exit 1
    fi
    usermod -aG docker $USER
}

download_docker_images()
{
    log_info "----------下载Phala Docker镜像----------"
    local res=0

    docker pull swr.cn-east-3.myhuaweicloud.com/phala/phala-poc3-node
    res=$(($?|$res))
    docker pull swr.cn-east-3.myhuaweicloud.com/phala/phala-poc3-pruntime
    res=$(($?|$res))
    docker pull swr.cn-east-3.myhuaweicloud.com/phala/phala-poc3-phost
    res=$(($?|$res))

    if [ $res -ne 0 ]; then
        log_err "----------下载 Docker 镜像失败----------"
        exit 1
    fi
}

remove_dirver()
{
    log_info "----------删除旧版本 dcap/isgx 驱动----------"
    local res_isgx=$(ls /dev | grep isgx)
    local res_sgx=$(ls /dev | grep sgx)
    if [ x"$res_isgx" == x"isgx" ] || [ x"$res_sgx" == x"sgx" ]; then
        /opt/intel/sgxdriver/uninstall.sh
        if [ $? -ne 0 ]; then
            log_info "----------删除旧版本 dcap/isgx 驱动失败----------"
            exit 1
        fi
    fi
}

install_driver()
{
    remove_dirver
    log_info "----------下载 DCAP 驱动----------"
    local driverbin=sgx_linux_x64_driver_1.36.2.bin
    local driverurl=https://download.01.org/intel-sgx/sgx-dcap/1.9/linux/distro/ubuntu18.04-server/sgx_linux_x64_driver_1.36.2.bin
    wget $driverurl

    if [ $? -ne 0 ]; then
        log_err "----------下载 DCAP 驱动失败----------"
        exit 1
    fi

    log_info "----------添加运行权限----------"
    chmod +x $driverbin

    log_info "----------尝试安装DCAP驱动----------"
    ./$driverbin

    local res_dcap=$(ls /dev | grep sgx)
    if [ x"$res_dcap" == x"" ]; then
        log_err "----------安装DCAP驱动失败，尝试安装isgx驱动----------"
        remove_dirver
        log_info "----------下载 isgx 驱动----------"
        driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
        driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu18.04-server/sgx_linux_x64_driver_2.6.0_b0a445b.bin
        wget $driverurl
        
        if [ $? -ne 0 ]; then
            log_err "----------下载 isgx 驱动失败----------"
            exit 1
        fi

        log_info "----------添加运行权限----------"
        chmod +x $driverbin

        log_info "----------安装 isgx 驱动----------"
        ./$driverbin

        local res_sgx=$(ls /dev | grep isgx)
        if [ x"$res_sgx" == x"" ]; then
            log_err "----------安装 isgx 驱动失败，请检查主板BIOS----------"
            exit 1
        fi

        log_info "----------删除临时文件----------"
        rm $driverbin
    fi

    log_success "----------删除临时文件----------"
    rm $driverbin
}

install_dcap()
{
    remove_dirver
    log_info "----------下载 DCAP 驱动----------"
    local driverbin=sgx_linux_x64_driver_1.36.2.bin
    local driverurl=https://download.01.org/intel-sgx/sgx-dcap/1.9/linux/distro/ubuntu18.04-server/sgx_linux_x64_driver_1.36.2.bin
    wget $driverurl

    if [ $? -ne 0 ]; then
        log_err "----------下载 DCAP 驱动失败----------"
        exit 1
    fi

    log_info "----------添加运行权限----------" 
    chmod +x $driverbin

    log_info "----------安装DCAP驱动----------"
    ./$driverbin

    local res_dcap=$(ls /dev | grep sgx)
    if [ x"$res_sgx" == x"" ]; then
        log_err "----------安装DCAP驱动失败----------"
        exit 1
    fi

    log_success "----------删除临时文件----------"
    rm $driverbin
}

install_isgx()
{
    remove_dirver
    log_info "----------下载 isgx 驱动----------"
    local driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
    local driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu18.04-server/sgx_linux_x64_driver_2.6.0_b0a445b.bin
    wget $driverurl
    
    if [ $? -ne 0 ]; then
        log_err "----------下载 isgx 驱动失败----------"
        exit 1
    fi

    log_info "----------添加运行权限----------"
    chmod +x $driverbin

    log_info "----------安装 isgx 驱动----------"
    ./$driverbin

    local res_sgx=$(ls /dev | grep isgx)
    if [ x"$res_sgx" == x"" ]; then
        log_err "----------安装 isgx 驱动失败----------"
        exit 1
    fi

    log_success "----------删除临时文件----------"
    rm $driverbin
}

install()
{
    case "$1" in
		init)
            install_depenencies
            download_docker_images
			config_set_all
            install_driver
			;;
		dcap)
			install_dcap
			;;
        isgx)
			install_isgx
			;;
		*)
            log_err "----------参数错误----------"
			exit 1
            ;;
	esac

    exit 0
}