#!/bin/bash

source $WORKSPACE/libfabric-ci-scripts/wget_check.sh
execution_seq=1
BUILD_CODE=0
output_dir=${output_dir:-$(mktemp -d -p $WORKSPACE)}
tmp_script=${tmp_script:-$(mktemp -p $WORKSPACE)}
# set default architecture of ami as x86_64
ami_arch=${ami_arch:-"x86_64"}
if [ ! "$ami_arch" = "x86_64" ] && [ ! "$ami_arch" = "aarch64" ]; then
    echo "Unknown architecture, ami_arch must be x86_64 or aarch64"
    exit 1
fi
RUN_IMPI_TESTS=${RUN_IMPI_TESTS:-1}
ENABLE_PLACEMENT_GROUP=${ENABLE_PLACEMENT_GROUP:-0}
TEST_SKIP_KMOD=${TEST_SKIP_KMOD:-0}
BUILD_GDR=${BUILD_GDR:-0}

get_opensuse1502_ami_id() {
    region=$1
    # OpenSUSE does not suppport ARM AMI's
    # openSUSE-Leap-15.2 Build7.1 cabelo@opensuse.org
    aws ec2 describe-images --owners aws-marketplace \
        --filters 'Name=product-code,Values=5080kaujzrzibjdwrkruspbj7' 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_sles15sp2_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="x86_64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ec2 describe-images --owners amazon \
        --filters "Name=name,Values=suse-sles-15-sp2-?????????-hvm-ssd-${ami_arch_label}" 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_alinux_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn-ami-hvm-x86_64-gp2 \
            --region $region | jq -r ".Parameters[0].Value"
    fi
    return $?
}

get_alinux2_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="x86_64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-${ami_arch_label}-gp2 \
        --region $region | jq -r ".Parameters[0].Value"
    return $?
}

get_ubuntu1604_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="amd64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ec2 describe-images --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-${ami_arch_label}-server-????????" \
        'Name=state,Values=available' 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_ubuntu1804_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="amd64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ec2 describe-images --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-${ami_arch_label}-server-????????" \
        'Name=state,Values=available' 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_ubuntu2004_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="amd64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ec2 describe-images --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-${ami_arch_label}-server-????????" \
        'Name=state,Values=available' 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_centos7_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="x86_64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="aarch64"
    fi
    aws ec2 describe-images --owners 125523088429 \
        --filters "Name=name,Values=CentOS 7*${ami_arch_label}*" 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_centos8_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="x86_64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="aarch64"
    fi
    aws ec2 describe-images --owners 125523088429 \
        --filters "Name=name,Values=CentOS 8*${ami_arch_label}*" 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_rhel76_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="x86_64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ec2 describe-images --owners 309956199498 \
        --filters "Name=name,Values=RHEL-7.6_HVM_GA*${ami_arch_label}*" \
        'Name=state,Values=available' 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_rhel77_ami_id() {
    region=$1
    # Currently rhel77 does not have arm version.
    if [ "$ami_arch" = "x86_64" ]; then
        aws ec2 describe-images --owners 309956199498 \
            --filters 'Name=name,Values=RHEL-7.7_HVM_GA*x86_64*' \
            'Name=state,Values=available' 'Name=ena-support,Values=true' \
            --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    fi
    return $?
}

get_rhel78_ami_id() {
    region=$1
    # Currently rhel78 does not have arm version.
    if [ "$ami_arch" = "x86_64" ]; then
        aws ec2 describe-images --owners 309956199498 \
            --filters 'Name=name,Values=RHEL-7.8_HVM_GA*x86_64*' \
            'Name=state,Values=available' 'Name=ena-support,Values=true' \
            --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    fi
    return $?
}

get_rhel82_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="x86_64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ec2 describe-images --owners 309956199498 \
        --filters "Name=name,Values=RHEL-8.2*${ami_arch_label}*" \
        'Name=state,Values=available' 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

get_rhel83_ami_id() {
    region=$1
    if [ "$ami_arch" = "x86_64" ]; then
        ami_arch_label="x86_64"
    elif [ "$ami_arch" = "aarch64" ]; then
        ami_arch_label="arm64"
    fi
    aws ec2 describe-images --owners 309956199498 \
        --filters "Name=name,Values=RHEL-8.3*${ami_arch_label}*" \
        'Name=state,Values=available' 'Name=ena-support,Values=true' \
        --output json --region $region | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'
    return $?
}

create_pg()
{
    if [ ${ENABLE_PLACEMENT_GROUP} -eq 0 ]; then
        return 0
    fi
    #Month - Day - Year - Hour - Minute - Second
    date_time=$(date +'%m-%d-%Y-%H-%M-%S')
    PLACEMENT_GROUP="slave-pg-${date_time}-${BUILD_NUMBER}-${RANDOM}"
    AWS_DEFAULT_REGION=us-west-2 aws ec2 create-placement-group \
        --group-name ${PLACEMENT_GROUP} \
        --strategy cluster
    return $?
}

delete_pg()
{
    if [ ${ENABLE_PLACEMENT_GROUP} -eq 0 ] || [ -z $PLACEMENT_GROUP ]; then
        return 0
    fi
    AWS_DEFAULT_REGION=us-west-2 aws ec2 delete-placement-group \
        --group-name ${PLACEMENT_GROUP}
    return $?
}

# Launches EC2 instances.
create_instance()
{
    # TODO: the labels need to be fixed in LibfabricCI and the stack
    # redeployed for PR testing
    if [[ $PULL_REQUEST_REF == *pr* ]]; then
        case "${label}" in
            rhel)
                ami[0]=$(get_rhel76_ami_id $AWS_DEFAULT_REGION)
                ;;
            ubuntu)
                ami[0]=$(get_ubuntu1804_ami_id $AWS_DEFAULT_REGION)
                ;;
            alinux)
                ami[0]=$(get_alinux2_ami_id $AWS_DEFAULT_REGION)
                ;;
            *)
                exit 1
        esac
    fi
    # If a specific subnet ID is provided by the caller, use that instead of
    # querying the VPC for all subnets.
    if [[ -n ${BUILD_SUBNET_ID} ]]; then
        subnet_ids=${BUILD_SUBNET_ID}
    else
        # Get a list of subnets within the VPC relevant to the Slave SG
        vpc_id=$(AWS_DEFAULT_REGION=us-west-2 aws ec2 describe-security-groups \
            --group-ids ${slave_security_group} \
            --query SecurityGroups[0].VpcId --output=text)
        subnet_ids=$(AWS_DEFAULT_REGION=us-west-2 aws ec2 describe-subnets \
            --filters "Name=availability-zone,Values=[us-west-2a,us-west-2b,us-west-2c]" \
                        "Name=vpc-id,Values=$vpc_id" \
                        --query "Subnets[*].SubnetId" --output=text)
    fi

    INSTANCE_IDS=''
    SERVER_ERROR=(
    InsufficientInstanceCapacity
    RequestLimitExceeded
    ServiceUnavailable
    Unavailable
    Unsupported
    )
    create_instance_count=0
    error=1
    if [ $ami_arch = "x86_64" ] && [ $BUILD_GDR -eq 0 ]; then
        case "${PROVIDER}" in
            efa)
                instance_type=c5n.18xlarge
                network_interface="[{\"DeviceIndex\":0,\"DeleteOnTermination\":true,\"InterfaceType\":\"efa\",\"Groups\":[\"${slave_security_group}\"]"
                # Opensuse Leap AMI is not supported on m5n.24xlarge instance
                if [[ ${label} == "suse" ]]; then
                    instance_type=c5n.18xlarge
                fi
                ;;
            tcp|udp|shm)
                instance_type=c5.18xlarge
                network_interface="[{\"DeviceIndex\":0,\"DeleteOnTermination\":true,\"Groups\":[\"${slave_security_group}\"]"
                ;;
            *)
                exit 1
        esac
    elif [ $BUILD_GDR -eq 1 ]; then
        instance_type=p4d.24xlarge
        network_interface="[{\"DeviceIndex\":0,\"DeleteOnTermination\":true,\"InterfaceType\":\"efa\",\"Groups\":[\"${slave_security_group}\"]"
    else
        instance_type=a1.4xlarge
        network_interface="[{\"DeviceIndex\":0,\"DeleteOnTermination\":true,\"Groups\":[\"${slave_security_group}\"]"
    fi
    addl_args=""
    if [ ${ENABLE_PLACEMENT_GROUP} -eq 1 ]; then
        echo "==> Creating placement group"
        create_pg || return 1
        addl_args+=" --placement GroupName=${PLACEMENT_GROUP}"
    fi
    if [[ -n ${USER_DATA_FILE} && -f ${USER_DATA_FILE} ]]; then
        addl_args+=" --user-data file://${USER_DATA_FILE}"
    fi
    # NVIDIA drivers and CUDA toolkit are large, allocate more EBS space for them.
    if [ "$ami_arch" = "x86_64" ]; then
        dev_name=$(aws ec2 describe-images --image-id ${ami[0]} --query 'Images[*].RootDeviceName' --output text)
        addl_args="${addl_args} --block-device-mapping=[{\"DeviceName\":\"${dev_name}\",\"Ebs\":{\"VolumeSize\":64}}]"
    fi

    echo "==> Creating instances"
    while [ ${error} -ne 0 ] && [ ${create_instance_count} -lt 30 ]; do
        for subnet in ${subnet_ids[@]}; do
            error=1
            set +e
            INSTANCE_IDS=$(AWS_DEFAULT_REGION=us-west-2 aws ec2 run-instances \
                    --tag-specification "ResourceType=instance,Tags=[{Key=Workspace,Value="${WORKSPACE}"},{Key=Name,Value=Slave},{Key=Build_Number,Value="${BUILD_NUMBER}"}]" \
                    --image-id ${ami[0]} \
                    --instance-type ${instance_type} \
                    --enable-api-termination \
                    --key-name ${slave_keypair} \
                    --network-interface ${network_interface}",\"SubnetId\":\"${subnet}\"}]" \
                    --count ${NODES}:${NODES} \
                    --query "Instances[*].InstanceId" \
                    --output=text ${addl_args} 2>&1)
            create_instance_exit_code=$?
            set -e
            echo "${INSTANCE_IDS}"
            # If run-instances is successful break from both the loops, else
            # find out whether the error was due to SERVER_ERROR or some other error
            if [ $create_instance_exit_code -ne 0 ]; then
                # If the error was due to SERVER_ERROR, set error=1 else for
                # some other error set error=0
                for code in ${SERVER_ERROR[@]}; do
                    if [[ "${INSTANCE_IDS}" == *${code}* ]]; then
                        error=1
                        break
                    else
                        error=0
                    fi
                done
            else
                break 2
            fi
            # If run-instances wasn't successful, and it was due to some other
            # error, exit and fail the test.
            if [ ${error} -eq 0 ]; then
                # Mark build as unstable, error code 65 has been used to
                # identify unstable build
                exit 65
            fi
        done
        sleep 2m
        create_instance_count=$((create_instance_count+1))
    done
}

# Get IP address for instances
get_instance_ip()
{
    execution_seq=$((${execution_seq}+1))
    INSTANCE_IPS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_IDS[@]} \
                        --query "Reservations[*].Instances[*].PrivateIpAddress" \
                        --output=text)
}

# disable nouveau open source driver on instances.
disable_nouveau()
{
    test_ssh $1
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -T -i ~/${slave_keypair} ${ami[1]}@"$1" \
        "bash -s" -- < $WORKSPACE/libfabric-ci-scripts/disable-nouveau.sh 2>&1 | tr \\r \\n | sed 's/\(.*\)/'$1' \1/'
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Disabling nouveau failed on $1"
        exit 1
    fi
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -T -i ~/${slave_keypair} ${ami[1]}@"$1" \
        "sudo reboot" 2>&1 | tr \\r \\n | sed 's/\(.*\)/'$1' \1/'
}

# Check provider and OS type, If EFA and Ubuntu then call ubuntu_kernel_upgrade
check_provider_os()
{
    if [ ${PROVIDER} == "efa" ] && [ ${label} == "ubuntu" ];then
        ubuntu_kernel_upgrade "$1"
    fi

    # Ensure we are on the latest CentOS version.
    if [ ${label} == "centos" ]; then
        test_ssh $1
        ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -T -i ~/${slave_keypair} ${ami[1]}@"$1" \
            "sudo yum -y upgrade && sudo reboot" 2>&1 | tr \\r \\n | sed 's/\(.*\)/'$1' \1/'
        execution_seq=$((${execution_seq}+1))
    fi
    if [ ${label} == "suse" ]; then
        test_ssh $1
        ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -T -i ~/${slave_keypair} ${ami[1]}@"$1" \
            "sudo zypper --gpg-auto-import-keys refresh -f && sudo zypper update -y && sudo pip install lxml --upgrade && sudo reboot" 2>&1 | tr \\r \\n | sed 's/\(.*\)/'$1' \1/'
    fi
}
#Test SLES15SP2 with allow unsupported modules
sles_allow_module()
{
    cat <<-"EOF" >> ${tmp_script}
    if [[ $(grep -Po '(?<=^NAME=).*' /etc/os-release) =~  .*SLES.* ]]; then
        sudo sed -i 's/allow_unsupported_modules .*/allow_unsupported_modules 1/' /etc/modprobe.d/10-unsupported-modules.conf
        line_number=$(grep -n "exit_sles15_efa_unsupported_module" efa_installer.sh | cut -d":" -f1 | tail -n1)
        sed -i "${line_number}s/.*/echo \"Allow unsupported modules for testing\"/" efa_installer.sh
    fi
EOF
}
# Creates a script, the script includes installation commands for
# different AMIs and appends libfabric script
script_builder()
{
    type=$1
    set_var
    ${label}_update
    # For rhel and centos we need to install wget, so we can download
    # EFA Installer
    if [ ${label} == "rhel" ] || [ ${label} == "centos" ]; then
        echo "sudo yum -y install wget" >> ${tmp_script}
    fi
    if [ $BUILD_GDR -eq 1 ]; then
        cat install-nvidia-driver.sh >> ${tmp_script}
        cat install-nvidia-fabric-manager.sh >> ${tmp_script}
    fi
    efa_software_components

    # The libfabric shm provider use CMA for communication. By default ubuntu
    # disallows non-child process ptrace by, which disable CMA.
    # Since libfabric 1.10, shm provider has a fallback solution, which will
    # be used when CMA is not available. Therefore, we turn off ptrace protection
    # for v1.9.x and v1.8.x
    if [ ${label} == "ubuntu" ]; then
        if [ ${TARGET_BRANCH} == "v1.9.x" ] || [ ${TARGET_BRANCH} == "v1.8.x" ];then
            echo "sudo sysctl -w kernel.yama.ptrace_scope=0" >> ${tmp_script}
        fi
    fi

    ${label}_install_deps
    # install CUDA toolkit only for non-gdr test on x86_64 platform.
    if [ "$ami_arch" = "x86_64" ] && [ "$BUILD_GDR" -eq 0 ]; then
        cat <<-"EOF" >> ${tmp_script}
        wget_check "https://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_450.51.06_linux.run" "cuda_11.0.3_450.51.06_linux.run"
        chmod +x cuda_11.0.3_450.51.06_linux.run
        sudo ./cuda_11.0.3_450.51.06_linux.run --silent --toolkit
        sudo ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/libcuda.so
EOF
    fi
    if [ -n "$LIBFABRIC_INSTALL_PATH" ]; then
        echo "LIBFABRIC_INSTALL_PATH=$LIBFABRIC_INSTALL_PATH" >> ${tmp_script}
    elif [ ${TARGET_BRANCH} == "v1.8.x" ]; then
        cat install-libfabric-1.8.sh >> ${tmp_script}
    else
        cat install-libfabric.sh >> ${tmp_script}
    fi

    # Run the MPI test for EFA and multi-node tests.
    # Open MPI will be installed by the EFA installer so use that, install
    # Intel MPI using the AWS script for now.
    if [ ${PROVIDER} == "efa" ] && [ ${type} == "multi-node" ] && [ ${RUN_IMPI_TESTS} -eq 1 ]; then
            cat install-impi.sh >> ${tmp_script}
    fi

    cat install-fabtests.sh >> ${tmp_script}
    if [ $BUILD_GDR -eq 1 ]; then
        cat install-nccl.sh >> ${tmp_script}
        cat install-aws-ofi-nccl.sh >> ${tmp_script}
        cat install-nccl-tests.sh >> ${tmp_script}
    fi
}

alinux_update()
{
    cat <<-"EOF" >> ${tmp_script}
    sudo yum -y update
EOF
}

alinux_install_deps() {
    cat <<-"EOF" >> ${tmp_script}
    sudo yum -y groupinstall 'Development Tools'
EOF
}

rhel_update()
{
    cat <<-"EOF" >> ${tmp_script}
    sudo yum -y update
EOF
}

rhel_install_deps() {
    cat <<-"EOF" >> ${tmp_script}
    sudo yum -y groupinstall 'Development Tools'
    sudo yum -y install gcc-gfortran
    # python is needed for running fabtests,
    # which is not available on base rhel8 ami.
    if [ ! $(which python) ] && [ ! $(which python2) ] && [ ! $(which python3) ]; then
        sudo yum install -y python3
    fi
EOF
}

centos_update()
{
    # Update and reboot already handled in check_provider_os()
    return 0
}

centos_install_deps() {
    cat <<-"EOF" >> ${tmp_script}
    sudo yum -y groupinstall 'Development Tools'
    sudo yum -y install gcc-gfortran
    # python is needed for running fabtests,
    # which is not available on base centos8 ami.
    if [ ! $(which python) ] && [ ! $(which python2) ] && [ ! $(which python3) ]; then
        sudo yum install -y python3
    fi
EOF
}

ubuntu_update()
{
    cat <<-"EOF" >> ${tmp_script}
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
EOF
}

ubuntu_install_deps()
{
    cat <<-"EOF" >> ${tmp_script}
    sudo DEBIAN_FRONTEND=noninteractive apt -y install python
    sudo DEBIAN_FRONTEND=noninteractive apt -y install autoconf
    sudo DEBIAN_FRONTEND=noninteractive apt -y install libltdl-dev
    sudo DEBIAN_FRONTEND=noninteractive apt -y install make
    sudo DEBIAN_FRONTEND=noninteractive apt -y install gcc
    sudo DEBIAN_FRONTEND=noninteractive apt -y install g++
    sudo DEBIAN_FRONTEND=noninteractive apt -y install gfortran
EOF
}
suse_update()
{
    # Update and reboot already handled in check_provider_os()
    return 0
}

suse_install_deps() {
    cat <<-"EOF" >> ${tmp_script}
    sudo zypper install -y autoconf
    sudo zypper install -y libtool
    sudo zypper install -y automake
    sudo zypper install -y git-core
    sudo zypper install -y wget
    sudo zypper install -y gcc-c++
    sudo zypper install -y gcc-fortran
EOF
}

#Initialize variables
set_var()
{
    cat <<-"EOF" > ${tmp_script}
    #!/bin/bash
    set -xe
    source ~/wget_check.sh
    PULL_REQUEST_ID=$1
    PULL_REQUEST_REF=$2
    PROVIDER=$3
    echo "==>Installing OS specific packages"
EOF
}

# Poll for the SSH daemon to come up before proceeding.
# The SSH poll retries with exponential backoff.
# The initial backoff is 30s, and doubles for each retry, until 16 minutes.
test_ssh()
{
    slave_ready=1
    ssh_backoff=30
    set +xe
    echo "Testing SSH connection of instance $1"
    while [ $ssh_backoff -le 960 ]; do
        sleep ${ssh_backoff}s
        ssh -T -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o BatchMode=yes -i ~/${slave_keypair} ${ami[1]}@$1  hostname
        if [ $? -eq 0 ]; then
            slave_ready=0
            echo "SSH connection of instance $1 is ready"
            set -xe
            return 0
        fi
        ssh_backoff=$((ssh_backoff * 2))
        echo "SSH connection of instance $1 NOT ready, sleeping ${ssh_backoff} seconds and retry"
    done
    echo "The instance $1 failed SSH connection test"
    set -xe
    return 65
}

efa_software_components()
{
    if [ -z "$EFA_INSTALLER_URL" ]; then
        if [ ${TARGET_BRANCH} == "v1.8.x" ]; then
            EFA_INSTALLER_URL="https://efa-installer.amazonaws.com/aws-efa-installer-1.7.1.tar.gz"
        else
            EFA_INSTALLER_URL="https://efa-installer.amazonaws.com/aws-efa-installer-latest.tar.gz"
        fi
    fi
    echo "EFA_INSTALLER_URL=$EFA_INSTALLER_URL" >> ${tmp_script}
    cat <<-"EOF" >> ${tmp_script}
    wget_check "$EFA_INSTALLER_URL" "efa-installer.tar.gz"
    tar -xf efa-installer.tar.gz
    cd ${HOME}/aws-efa-installer
EOF
    # If we are not skipping the kernel module, then add a check for SLES
    if [ ${TEST_SKIP_KMOD} -eq 0 ]; then
            sles_allow_module
    fi
    if [ $TEST_SKIP_KMOD -eq 1 ]; then
        echo "sudo ./efa_installer.sh -y -k" >> ${tmp_script}
    elif [ $BUILD_GDR -eq 1 ]; then
        echo "sudo ./efa_installer.sh -y -g" >> ${tmp_script}
    else
        echo "sudo ./efa_installer.sh -y" >> ${tmp_script}
    fi
    echo ". /etc/profile.d/efa.sh" >> ${tmp_script}
}

ubuntu_kernel_upgrade()
{
    test_ssh $1
    cat <<-"EOF" > ubuntu_kernel_upgrade.sh
    set -xe
    echo "==>System will reboot after kernel upgrade"
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y --with-new-pkgs -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
    sudo reboot
EOF
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -T -i ~/${slave_keypair} ${ami[1]}@"$1" \
        "bash -s" -- < $WORKSPACE/libfabric-ci-scripts/ubuntu_kernel_upgrade.sh \
        2>&1 | tr \\r \\n | sed 's/\(.*\)/'$1' \1/'
    execution_seq=$((${execution_seq}+1))
}

# Download the fabtest parser file and modify it locally to show results for
# Excluded files as skipped as well. Currently only Notrun files are displayed
# as skipped
get_rft_yaml_to_junit_xml()
{
    pushd ${output_dir}
    # fabtests junit parser script
    wget_check "https://raw.githubusercontent.com/ofiwg/libfabric/master/fabtests/scripts/rft_yaml_to_junit_xml" "rft_yaml_to_junit_xml"
    # Add Excluded tag
    sed -i "s,<skipped />,<skipped />\n    EOT\n  when 'Excluded'\n    puts <<-EOT\n    <skipped />,g" rft_yaml_to_junit_xml
    sed -i "s,skipped += 1,skipped += 1\n  when 'Excluded'\n    skipped += 1,g" rft_yaml_to_junit_xml
    popd
}

# Split out output files into fabtest build and fabtests, this is done to
# separate the output. As long as INSTANCE_IPS[0] is used, this can be
# common for both single node and multinode
split_files()
{
    pushd ${output_dir}
    csplit -k temp_execute_runfabtests.txt '/- name/'
    # If the installation failed, fabtests will not have run. In that case, do
    # not split the file.
    if [ $? -ne 0 ]; then
        execution_seq=$((${execution_seq}+1))
        mv temp_execute_runfabtests.txt ${execution_seq}_${INSTANCE_IPS[0]}_install_libfabric_or_fabtests_parameters.txt
    else
        execution_seq=$((${execution_seq}+1))
        mv xx00 ${execution_seq}_${INSTANCE_IPS[0]}_install_libfabric_or_fabtests_parameters.txt
        execution_seq=$((${execution_seq}+1))
        mv xx01 ${execution_seq}_${INSTANCE_IPS[0]}_fabtests.txt
    fi
    rm temp_execute_runfabtests.txt

    execution_seq=$((${execution_seq}+1))
    mv temp_execute_ring_c_ompi.txt ${execution_seq}_${INSTANCE_IPS[0]}_ring_c_ompi.txt
    execution_seq=$((${execution_seq}+1))
    mv temp_execute_osu_ompi.txt ${execution_seq}_${INSTANCE_IPS[0]}_osu_ompi.txt
    if [ ${RUN_IMPI_TESTS} -eq 1 ]; then
        execution_seq=$((${execution_seq}+1))
        mv temp_execute_ring_c_impi.txt ${execution_seq}_${INSTANCE_IPS[0]}_ring_c_impi.txt
        execution_seq=$((${execution_seq}+1))
        mv temp_execute_osu_impi.txt ${execution_seq}_${INSTANCE_IPS[0]}_osu_impi.txt
    fi
    if [ ${BUILD_GDR} -eq 1 ]; then
        execution_seq=$((${execution_seq}+1))
        mv temp_execute_nccl_tests.txt ${execution_seq}_${INSTANCE_IPS[0]}_nccl_tests.txt
    fi
    popd
}
# Parses the output text file to yaml and then runs rft_yaml_to_junit_xml script
# to generate junit xml file. Calls parse_fabtests function for fabtests result.
# For general text file assign commands yaml -name tags, the output of these
# commands will be assigned server_stdout tag
parse_txt_junit_xml()
{
    exit_code=$?
    set +x
    pushd ${output_dir}
    get_rft_yaml_to_junit_xml
    # Read all .txt files
    for file in *.txt; do
        if [[ ${file} == '*.txt' ]]; then
            continue
        fi
        # Get instance id or instance ip from the file name
        instance_ip_or_id=($(echo ${file} | tr "_" "\n"))
        N=${#instance_ip_or_id[@]}
        file_name=${file/.txt/}
        # Line number to arrange commands sequentially
        line_no=1
        # If the first line of the file does not have a + (+ indicates command)
        # then insert ip/id and + only if its not empty, this is only for non
        # fabtests.txt file
        if [[ ${instance_ip_or_id[$(($N-1))]} != 'fabtests.txt' ]]; then
            sed -i "1s/\(${instance_ip_or_id[1]} [+]\+ \)*\(.\+\)/${instance_ip_or_id[1]} + \2/g" ${file}
        else
            parse_fabtests ${file}
            continue
        fi
        while read line; do
            # If the line is a command indicated by + sign then assign name tag
            # to it, command is the testname used in the xml
            if [[ ${line} == *${instance_ip_or_id[1]}' +'* ]]; then
                # Junit deosn't accept quotes or colons or less than sign in
                # testname in the xml, convert them to underscores. Parse the
                # command to yaml, by inserting - name tag before the command
                echo ${line//[\"<:]/_} | sed "s/\(${instance_ip_or_id[1]} [+]\+\)\(.*\)/- name: $(printf '%08d\n' $line_no)-\2\n  time: 0\n  result:\n  server_stdout: |/g" \
                >> ${file_name}
                line_no=$((${line_no}+1))
            else
                # These are output lines and are put under server_stdout tag
                echo "    "${line}  >> ${file_name}
            fi
        done < ${file}
        junit_xml ${file_name}
    done
    popd
    set -x
}

# Parses the fabtest result to xml. One change has been done to accomodate yaml
# file creation if fabtest fails. All output other than name,time,result will be
# grouped under server_stdout.
parse_fabtests()
{
    pushd ${output_dir}
    while read line; do
        # If the line has - name: it indicates its a fabtests command and is
        # already yaml format, it already has name tag. It is the testname
        # used in the xml
        if [[ ${line} == *${instance_ip_or_id[1]}' - 'name:* ]]; then
            echo ${line//[\"]/_} | sed "s/\(${instance_ip_or_id[1]} [-] name: \)\(.*\)/- name: \2/g" >> ${file_name}
        elif [[ ${line} == *'time: '* ]]; then
            echo ${line} | sed "s/\(${instance_ip_or_id[1]}\)\(.*time:.*\)/ \2\n  server_stdout: |/g" >> ${file_name}
        else
            # Yaml spacing for result tag should be aligned with name,
            # time, server_stdout tags; whereas all other should be under
            # server_stdout tag
            echo ${line} | sed "s/\(${instance_ip_or_id[1]}\)\(.*\(result\):.*\)*\(.*\)/ \2  \4/g" >> ${file_name}
        fi
        line_no=$((${line_no}+1))
    done < $1
    junit_xml ${file_name}
    popd
}

# It updates the filename in rft_yaml_to_junit_xml on the fly to the file_name
# which is the function_name. If the file is empty it doesn't call the
# rft_yaml_to_junit_xml instead creates the xml itself
junit_xml()
{
    pushd ${output_dir}
    file_name=$1
    file_name_xml=${file_name//[.-]/_}
    # If the yaml file is not empty then convert it to xml using
    # rft_yaml_to_junit_xml else create an xml for empty yaml
    if [ -s ${file_name} ]; then
        sed -i "s/\(testsuite name=\)\(.*\)\(tests=\)/\1\"${file_name_xml}\" \3/g" rft_yaml_to_junit_xml
        # TODO: change this, we should only use this ruby script for fabtests.
        ruby rft_yaml_to_junit_xml < ${file_name} > ${file_name_xml}.xml || true
        # Check MPI tests for pass/failure and update the xml if a failure
        # occurred.
        if [[ ${file_name} =~ "ompi" ]] || [[ ${file_name} =~ "impi" ]]; then
            if ! grep -q "Test Passed" ${file_name_xml}.xml; then
                sed -i 's/failures="0"/failures="1"/' ${file_name_xml}.xml
            fi
        fi
    else
        cat<<-EOF > ${file_name_xml}.xml
<testsuite name="${file_name_xml}" tests="${file_name_xml}" skipped="0" time="0.000">
    <testcase name="${file_name_xml}" time="0">
    </testcase>
</testsuite>
EOF
    fi
    popd
}

terminate_instances()
{
    # Terminates slave node
    if [[ ! -z ${INSTANCE_IDS[@]} ]]; then
        AWS_DEFAULT_REGION=us-west-2 aws ec2 terminate-instances --instance-ids ${INSTANCE_IDS[@]}
        AWS_DEFAULT_REGION=us-west-2 aws ec2 wait instance-terminated --instance-ids ${INSTANCE_IDS[@]}
    fi
}

on_exit()
{
    return_code=$?
    set +e
    # Some of the commands run are background procs, wait for them.
    wait
    split_files
    parse_txt_junit_xml
    terminate_instances
    # Not sure why 'wait instance-terminated' isn't good enough here as I am
    # sometimes seeing an in-use error when attempting to delete the placement
    # group. Add a small delay as a workaround.
    sleep 1
    delete_pg
    return $return_code
}

exit_status()
{
    if [ $1 -ne 0 ];then
        BUILD_CODE=1
        echo "Build failure on $2"
    else
        BUILD_CODE=0
        echo "Build success on $2"
    fi
}
