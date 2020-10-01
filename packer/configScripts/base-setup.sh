#!/bin/bash -xe
###############################################################################
#               Note: Packer runs this scipt from root                        #
###############################################################################

#sudo -H -u ubuntu -c 'exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1'

###############################################################################
#                           SYSTEM CONFIGURE                                  #
###############################################################################
# Don't need this stuff...it just takes up space
# This is the stuff that comes preinstalled on the AWS deep learning AMI
rm -r $HOME/tutorials/ $HOME/examples/ $HOME/anaconda3/ $HOME/README $HOME/LICENSE $HOME/tools $HOME/Nvidia_Cloud_EULA.pdf

cd $HOME
sudo apt update && sudo apt upgrade -y

sudo apt-get install -y make mesa-opencl-icd ocl-icd-opencl-dev gcc git bzr jq pkg-config curl awscli jq numactl sysstat cmake libncurses5-dev libncursesw5-dev clang


# This is suggested optimization for heavy GPU load on AWS
# See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/optimize_gpu.html
sudo -H -u $USER PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin bash -c 'sudo nvidia-persistenced'
sudo -H -u $USER PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin bash -c 'sudo nvidia-smi -ac 5001,1590'

########## Ulimits #############

echo "*  soft  nproc  10485761048576
*  hard  nproc  1048576
*  soft  nofile 1048576
*  hard  nofile 1048576" | sudo tee -a  /etc/security/limits.d/lotus-limits.conf

echo "*  soft  nproc  1048576
*  hard  nproc  1048576
*  soft  nofile 1048576
*  hard  nofile 1048576
" | sudo tee -a /etc/security/limits.conf


########## Bashrc Extras #############
echo "
alias lmi='lotus-miner info'
alias lsj='lotus-miner sealing jobs'
alias lsw='lotus-miner sealing workers'
alias lpi='lotus-miner proving info'
alias lsl='lotus-miner sectors list'
alias lms='lotus-miner sealing sched-diag'
alias mklotus='pushd ~/lotus && git fetch origin master &&
git checkout master &&
git pull && sudo PATH=$PATH make clean && sudo RUSTFLAGS=\"-C target-cpu=native -g\" FFI_BUILD_FROM_SOURCE=1 PATH=$PATH make all -j\`nproc\` && sudo PATH=$PATH make install && popd'
alias less='less -r'

export EDITOR=vim
export PAGER=\"less\"
" | sudo tee -a ~/.bashrc


###############################################################################
#                                 INSTALL RUST                                #
###############################################################################

sudo -H -u $USER bash -c 'curl https://sh.rustup.rs -sSf | sh -s -- -y'
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/.cargo/bin" >> $HOME/.bashrc


###############################################################################
#                                  INSTALL GO                                 #
###############################################################################

wget https://golang.org/dl/go1.14.4.linux-amd64.tar.gz
sudo -H -u $USER bash -c 'sudo tar -C /usr/local -xzf go1.14.4.linux-amd64.tar.gz'
sudo -H -u $USER bash -c 'rm $HOME/go1.14.4.linux-amd64.tar.gz'
export PATH=$PATH:/usr/local/go/bin

sudo -H -u $USER bash -c 'mkdir $HOME/.go'
GOROOT=/usr/local/go
GOPATH=$HOME/.go
PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin

sudo update-alternatives --install "/usr/bin/go" "go" "/usr/local/go/bin/go" 0
sudo update-alternatives --set go /usr/local/go/bin/go

sudo -H -u $USER bash -c 'source $HOME/.bashrc'


###############################################################################
#                              BUILD NVTOP                                    #
###############################################################################
#NVTOP is used to monitor processes running on the GPU

sudo -H -u $USER bash -c 'git clone https://github.com/Syllo/nvtop.git'
sudo -H -u $USER bash -c 'mkdir -p $HOME/nvtop/build'
cd $HOME/nvtop/build
sudo -H -u $USER bash -c 'cmake .. && make && sudo make install'
cd $HOME


###############################################################################
#                              BUILD LOTUS                                    #
###############################################################################

sudo -H -u $USER bash -c 'git clone https://github.com/filecoin-project/lotus.git'
cd lotus/
sudo -H -u $USER bash -c 'git fetch origin master; git checkout master'

export RUSTFLAGS="-C target-cpu=native -g"
export FFI_BUILD_FROM_SOURCE=1
export FIL_PROOFS_MAXIMIZE_CACHING=1
export FIL_PROOFS_SDR_PARENTS_CACHE_SIZE=4096
export FIL_PROOFS_USE_GPU_COLUMN_BUILDER=1
export FIL_PROOFS_USE_GPU_TREE_BUILDER=1
export FIL_PROOFS_USE_FIL_BLST=1

# Runtime flags for FFI proofs
echo "export RUSTFLAGS=\"-C target-cpu=native -g\"
export FFI_BUILD_FROM_SOURCE=1
export FIL_PROOFS_MAXIMIZE_CACHING=1
export FIL_PROOFS_SDR_PARENTS_CACHE_SIZE=4096
export FIL_PROOFS_USE_GPU_COLUMN_BUILDER=1
export FIL_PROOFS_USE_GPU_TREE_BUILDER=1
export FIL_PROOFS_USE_FIL_BLST=1" >> $HOME/.bashrc



sudo -H -u $USER PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin bash -c 'sudo make clean && sudo RUSTFLAGS="-C target-cpu=native -g" FFI_BUILD_FROM_SOURCE=1 PATH=$PATH make all -j`nproc`'
sudo -H -u $USER PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin bash -c 'sudo make install'

#Required for systemd daemon
sudo -H -u $USER PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin bash -c 'sudo make install-chainwatch'
sudo -H -u $USER PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin bash -c 'sudo make install-all-services'

###############################################################################
#                            PREFETCH PROOFS                                  #
###############################################################################
#Prefetching the params saves ~1 hour of proof fetching time.
sudo -H -u $USER bash -c 'lotus fetch-params 32GiB'

sudo PATH=$PATH make clean && sudo RUSTFLAGS="-C target-cpu=native -g" FFI_BUILD_FROM_SOURCE=1 PATH=$PATH make all -j`nproc` && sudo PATH=$PATH make install
