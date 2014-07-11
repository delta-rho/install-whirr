#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
function configure_cdh_hadoop() {
  local OPTIND
  local OPTARG
  
  if [ "$CONFIGURE_HADOOP_DONE" == "1" ]; then
    echo "Hadoop is already configured."
    return;
  fi
  
  ROLES=$1
  shift
  
  REPO=${REPO:-cdh4}
  CDH_MAJOR_VERSION=$(echo $REPO | sed -e 's/cdh\([0-9]\).*/\1/')
  if [ $CDH_MAJOR_VERSION = "4" ]; then
    HADOOP=hadoop
    HADOOP_CONF_DIR=/etc/$HADOOP/conf.dist
    HDFS_PACKAGE_PREFIX=hadoop-hdfs
    MAPREDUCE_PACKAGE_PREFIX=hadoop-0.20-mapreduce
  else
    HADOOP=hadoop-${HADOOP_VERSION:-0.20}
    HADOOP_CONF_DIR=/etc/$HADOOP/conf.dist
    HDFS_PACKAGE_PREFIX=hadoop-${HADOOP_VERSION:-0.20}
    MAPREDUCE_PACKAGE_PREFIX=hadoop-${HADOOP_VERSION:-0.20}  
  fi
  
  make_hadoop_dirs /data*

  # Copy generated configuration files in place
  cp /tmp/{core,hdfs,mapred}-site.xml $HADOOP_CONF_DIR
  cp /tmp/hadoop-env.sh $HADOOP_CONF_DIR
  cp /tmp/hadoop-metrics.properties $HADOOP_CONF_DIR

  # Keep PID files in a non-temporary directory
  HADOOP_PID_DIR=$(. /tmp/hadoop-env.sh; echo $HADOOP_PID_DIR)
  HADOOP_PID_DIR=${HADOOP_PID_DIR:-/var/run/hadoop}
  mkdir -p $HADOOP_PID_DIR
  chgrp -R hadoop $HADOOP_PID_DIR
  chmod -R g+w $HADOOP_PID_DIR

  # Create the actual log dir
  mkdir -p /data/hadoop/logs
  chgrp -R hadoop /data/hadoop/logs
  chmod -R g+w /data/hadoop/logs

  # Create a symlink at $HADOOP_LOG_DIR
  HADOOP_LOG_DIR=$(. /tmp/hadoop-env.sh; echo $HADOOP_LOG_DIR)
  HADOOP_LOG_DIR=${HADOOP_LOG_DIR:-/var/log/hadoop/logs}
  rm -rf $HADOOP_LOG_DIR
  mkdir -p $(dirname $HADOOP_LOG_DIR)
  ln -s /data/hadoop/logs $HADOOP_LOG_DIR
  chgrp -R hadoop $HADOOP_LOG_DIR
  chmod -R g+w $HADOOP_LOG_DIR

  if [ $(echo "$ROLES" | grep "hadoop-namenode" | wc -l) -gt 0 ]; then
    start_namenode
  fi
  
  for role in $(echo "$ROLES" | tr "," "\n"); do
    case $role in
    hadoop-secondarynamenode)
      start_hadoop_daemon $HDFS_PACKAGE_PREFIX-secondarynamenode
      ;;
    hadoop-jobtracker)
      start_hadoop_daemon $MAPREDUCE_PACKAGE_PREFIX-jobtracker
      ;;
    hadoop-datanode)
      start_hadoop_daemon $HDFS_PACKAGE_PREFIX-datanode
      ;;
    hadoop-tasktracker)
      start_hadoop_daemon $MAPREDUCE_PACKAGE_PREFIX-tasktracker
      ;;
    esac
  done
additional_pkg_installer
  
    CONFIGURE_HADOOP_DONE=1
  
}

function make_hadoop_dirs {
  for mount in "$@"; do
    if [ ! -e $mount/hadoop ]; then
      mkdir -p $mount/hadoop
      chgrp -R hadoop $mount/hadoop
      chmod -R g+w $mount/hadoop
    fi
    if [ ! -e $mount/tmp ]; then
      mkdir $mount/tmp
      chmod a+rwxt $mount/tmp
    fi
  done
}

function start_namenode() {
  if which dpkg &> /dev/null; then
    retry_apt_get -y install $HDFS_PACKAGE_PREFIX-namenode
    AS_HDFS="su -s /bin/bash - hdfs -c"
    # Format HDFS
    [ ! -e /data/hadoop/hdfs ] && $AS_HDFS "$HADOOP namenode -format"
  elif which rpm &> /dev/null; then
    retry_yum install -y $HDFS_PACKAGE_PREFIX-namenode
    AS_HDFS="/sbin/runuser -s /bin/bash - hdfs -c"
    # Format HDFS
    [ ! -e /data/hadoop/hdfs ] && $AS_HDFS "$HADOOP namenode -format"
  fi

  service $HDFS_PACKAGE_PREFIX-namenode start

  $AS_HDFS "$HADOOP dfsadmin -safemode wait"
  $AS_HDFS "/usr/bin/$HADOOP fs -mkdir /user"
  # The following is questionable, as it allows a user to delete another user
  # It's needed to allow users to create their own user directories
  $AS_HDFS "/usr/bin/$HADOOP fs -chmod +w /user"
  $AS_HDFS "/usr/bin/$HADOOP fs -mkdir /hadoop"
  $AS_HDFS "/usr/bin/$HADOOP fs -chmod +w /hadoop"
  $AS_HDFS "/usr/bin/$HADOOP fs -mkdir /hbase"
  $AS_HDFS "/usr/bin/$HADOOP fs -chmod +w /hbase"
  $AS_HDFS "/usr/bin/$HADOOP fs -mkdir /mnt"
  $AS_HDFS "/usr/bin/$HADOOP fs -chmod +w /mnt"

  # Create temporary directory for Pig and Hive in HDFS
  $AS_HDFS "/usr/bin/$HADOOP fs -mkdir /tmp"
  $AS_HDFS "/usr/bin/$HADOOP fs -chmod +w /tmp"
  $AS_HDFS "/usr/bin/$HADOOP fs -mkdir /user/hive/warehouse"
  $AS_HDFS "/usr/bin/$HADOOP fs -chmod +w /user/hive/warehouse"
}

function start_hadoop_daemon() {
  daemon=$1
  if which dpkg &> /dev/null; then
    retry_apt_get -y install $daemon
  elif which rpm &> /dev/null; then
    retry_yum install -y $daemon
  fi
  service $daemon start
}

function additional_pkg_installer() {
	install_preconfig
	preconfigure_rhipe
	install_protobuf
	install_rjava
	preconfigure_rlib
	install_rhipe
	install_ddr_tscope
	install_rstudio
	install_shiny_server
}

function install_preconfig() {
    ## other mirrors:  http://cran.r-project.org/mirrors.html
    	echo 'deb http://cran.fhcrc.org/bin/linux/ubuntu lucid/' >>  /etc/apt/sources.list
    	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
    	sudo apt-get update
    	sudo apt-get install -y r-base-dev r-recommended r-cran-rodbc ess pkg-config binutils-gold
}

function preconfigure_rhipe() {

	echo '/usr/lib/jvm/java-6-sun/jre/lib/amd64/server \n /usr/lib/jvm/java-6-sun/jre/lib/amd64' >> /etc/ld.so.conf.d/jre.conf
	echo '/usr/lib/hadoop \n /usr/lib/hadoop-0.20-mapreduce \n /usr/lib/hadoop-hdfs \n /usr/lib/hadoop/libs \n /usr/lib/hadoop-0.20-mapreduce/libs \n /usr/lib/hadoop-hdfs/libs' >> /etc/ld.so.conf.d/hadoop.conf
	sudo ldconfig

	export HADOOP=/usr/lib/hadoop:/usr/lib/hadoop-0.20-mapreduce:/usr/lib/hadoop-hdfs
	export HADOOP_HOME=$HADOOP
	export HADOOP_BIN=/usr/bin:/usr/lib/hadoop/bin:/usr/lib/hadoop-0.20-mapreduce/bin:/usr/lib/hadoop-hdfs/bin
	export HADOOP_LIBS=$HADOOP_HOME:/usr/lib/hadoop/libs:/usr/lib/hadoop-0.20-mapreduce/libs:/usr/lib/hadoop-hdfs/libs
	export HADOOP_CONF_DIR=/etc/hadoop/conf
	sudo echo 'export HADOOP=/usr/lib/hadoop:/usr/lib/hadoop-0.20-mapreduce:/usr/lib/hadoop-hdfs' >> /etc/bash.bashrc
	sudo echo 'export HADOOP_HOME=$HADOOP' >> /etc/bash.bashrc
	sudo echo 'export HADOOP_BIN=/usr/bin:/usr/lib/hadoop/bin:/usr/lib/hadoop-0.20-mapreduce/bin:/usr/lib/hadoop-hdfs/bin' >> /etc/bash.bashrc
	sudo echo 'export HADOOP_LIBS=$HADOOP_HOME:/usr/lib/hadoop/libs:/usr/lib/hadoop-0.20-mapreduce/libs:/usr/lib/hadoop-hdfs/libs' >> /etc/bash.bashrc
	sudo echo 'export HADOOP_CONF_DIR=/etc/hadoop/conf' >> /etc/bash.bashrc
	sudo echo 'HADOOP_BIN=/usr/bin:/usr/lib/hadoop/bin:/usr/lib/hadoop-0.20-mapreduce/bin:/usr/lib/hadoop-hdfs/bin' >> /etc/R/Renviron
	sudo echo 'HADOOP=/usr/lib/hadoop:/usr/lib/hadoop-0.20-mapreduce:/usr/lib/hadoop-hdfs' >> /etc/R/Renviron
	sudo echo 'HADOOP_HOME=/usr/lib/hadoop:/usr/lib/hadoop-0.20-mapreduce:/usr/lib/hadoop-hdfs' >> /etc/R/Renviron
	sudo echo 'HADOOP_LIBS=/usr/lib/hadoop:/usr/lib/hadoop-0.20-mapreduce:/usr/lib/hadoop-hdfs:/usr/lib/hadoop/libs:/usr/lib/hadoop-0.20-mapreduce/libs:/usr/lib/hadoop-hdfs/libs' >> /etc/R/Renviron
	sudo echo 'HADOOP_CONF_DIR=/etc/hadoop/conf' >> /etc/R/Renviron

}

function install_protobuf() {
    	wget http://protobuf.googlecode.com/files/protobuf-2.4.1.tar.gz -O /tmp/protobuf.tar.gz
	COME_BACK_DIR=`pwd`
	cd /tmp
    	sudo tar -xzf protobuf.tar.gz
    	cd protobuf-2.4.1
    	sudo ./configure
    	sudo make
    	sudo make install
    	sudo ldconfig
	cd $COME_BACK_DIR
}

function install_rjava() {
    	wget http://cran.r-project.org/src/contrib/rJava_0.9-6.tar.gz -O /tmp/rJava.tar.gz
    	sudo R CMD INSTALL /tmp/rJava.tar.gz
}

function preconfigure_rlib() {
        sudo su - -c "R -e \"install.packages('codetools', repos='http://cran.rstudio.com/')\""
        sudo su - -c "R -e \"install.packages('lattice', repos='http://cran.rstudio.com/')\""
        sudo su - -c "R -e \"install.packages('MASS', repos='http://cran.rstudio.com/')\""
        sudo su - -c "R -e \"install.packages('boot', repos='http://cran.rstudio.com/')\""
        sudo su - -c "R -e \"install.packages('shiny', repos='http://cran.rstudio.com/')\""
}

function install_rhipe() {
        wget http://ml.stat.purdue.edu/rhipebin/Rhipe_0.73.1.tar.gz -O /tmp/Rhipe.tar.gz
        sudo R CMD INSTALL /tmp/Rhipe.tar.gz
}

function install_ddr_tscope() {
	sudo apt-get -y install libcurl4-openssl-dev
        sudo su - -c "R -e \"install.packages('devtools', repos='http://cran.rstudio.com/')\""
        sudo su - -c "R -e \"options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('datadr', 'hafen')\""
        sudo su - -c "R -e \"options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('trelliscope', 'hafen')\""
}

function install_rstudio() {
	wget http://download2.rstudio.org/rstudio-server-0.98.507-amd64.deb -O /tmp/rstudio-server.deb
	sudo apt-get -y install gdebi-core
	sudo gdebi --n /tmp/rstudio-server.deb
#rstudio post configure
	sudo useradd -m user3
	sudo echo "user3:user3" | sudo chpasswd
}
function install_shiny_server(){

	GET_BACK_DIR=`pwd`
	cd /tmp
	#Compiling Cmake for Shiny Server
	wget http://www.cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz
	tar xzf cmake-2.8.12.2.tar.gz
	cd cmake-2.8.12.2
	./configure
	make
	
	cd /tmp	
	git clone https://github.com/rstudio/shiny-server.git
	sudo mkdir -p /etc/shiny-server
	sudo cp shiny-server/config/default.config /etc/shiny-server/shiny-server.conf

	# Get into a temporary directory in which we'll build the project
	cd shiny-server
	mkdir tmp
	cd tmp

	# Add the bin directory to the path so we can reference node
	DIR=`pwd`
	PATH=$PATH:$DIR/../bin/

	# See the "Python" section below if your default python version is not 2.6 or 2.7. 
	PYTHON=`which python`

	# Check the version of Python. If it's not 2.6.x or 2.7.x, see the Python section below.
	$PYTHON --version

	# Use cmake to prepare the make step. Modify the "--DCMAKE_INSTALL_PREFIX"
	# if you wish the install the software at a different location.
	../../cmake-2.8.12.2/bin/cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DPYTHON="$PYTHON" ../
	# Get an error here? Check the "How do I set the cmake Python version?" question below

	# Recompile the npm modules included in the project
	make -j4
	mkdir ../build
	(cd .. && bin/npm --python="$PYTHON" rebuild)
	# Need to rebuild our gyp bindings since 'npm rebuild' won't run gyp for us.
	(cd .. && ext/node/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js --python="$PYTHON" rebuild)

	# Install the software at the predefined location
	sudo make install

	# POST INSTALL
	# Place a shortcut to the shiny-server executable in /usr/bin
	sudo ln -s /usr/local/shiny-server/bin/shiny-server /usr/bin/shiny-server

	#Create shiny user. On some systems, you may need to specify the full path to 'useradd'
	sudo useradd -r -m shiny

	# Create log, config, and application directories
	sudo mkdir -p /var/log/shiny-server
	sudo mkdir -p /srv/shiny-server
	sudo mkdir -p /var/lib/shiny-server
	sudo chown shiny /var/log/shiny-server

	#copy shiny examples
	sudo mkdir /srv/shiny-server/examples
	sudo cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/examples
	sudo chown -R shiny:shiny /srv/shiny-server/examples
	cd $GET_BACK_DIR
	sudo -u shiny nohup shiny-server &
}
