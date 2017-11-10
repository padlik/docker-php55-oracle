#!/bin/bash
set -e

#Creates TNS entry in tnsnames.ora 
make_tns(){
	touch ${TNS_ADMIN}/tnsnames.ora
	echo "${TNS_NAME} =
	(DESCRIPTION =
	(ADDRESS = (PROTOCOL = TCP)(HOST = ${ORACLE_HOST})(PORT = ${ORACLE_PORT}))
	(CONNECT_DATA =
	(SERVER = DEDICATED)
	(SERVICE_NAME = ${ORACLE_SERVICE})
	)
	)" > ${TNS_ADMIN}/tnsnames.ora 
}


#Creates configuration entry in Apache required by SugarCRM
make_override(){
	mkdir -p $SUGAR_HOME
	OVR_CONF=/etc/apache2/conf-enabled/sugar.conf
	touch $OVR_CONF
	echo "<Directory ${SUGAR_HOME}/>
	Options Indexes FollowSymLinks
	AllowOverride All
	Require all granted 
	</Directory>" > $OVR_CONF
}

#Patch PHP settings
patch_phpini(){ 
	sed -i 's/memory_limit = .*/memory_limit = '${PHP_MEM_LIMIT}'/' /etc/php5/apache2/php.ini
	sed -i 's/upload_max_filesize = .*/upload_max_filesize = '${PHP_UPLOAD_LIMIT}'/' /etc/php5/apache2/php.ini
}

#Creates config_si.php for silent installation
make_install_configs(){
	#$1 - root installation folder
	sugar_root=$1
	sugar_si=$SUGAR_HOME/$sugar_root/config_si.php
	touch $sugar_si
	chown $APACHE_USER:$APACHE_GROUP $sugar_si

	url="http://localhost/$SUGAR_BASE/$sugar_root"
	dbuser=$DB_USER
	dbpwd=$DB_PASS

	case "$SUGAR_DB_TYPE" in
		oci8)
			wait_for_oracle
			db_name=$TNS_NAME
			db_host=$ORACLE_HOST
			crdb=0
			;;
		*)
			wait_for_mysql
			db_name="sugar"
			db_host=$MYSQL_HOST
			crdb=1
			;;
	esac

	echo "
	<?php

	\$sugar_config_si = array (
	'setup_site_admin_user_name'=>'admin',
	'setup_site_admin_password' => 'admin',
	'setup_fts_type' => 'Elastic',
	'setup_fts_host' => '$ELASTIC_HOST',
	'setup_fts_port' => '$ELASTIC_PORT',

	'setup_db_host_name' => '$db_host',
	'setup_db_database_name' => '$db_name',
	'setup_db_drop_tables' => 1,
	'setup_db_create_database' => $crdb,
	'setup_db_admin_user_name' => '$dbuser',
	'setup_db_admin_password' => '$dbpwd',
	'setup_db_type' => '$SUGAR_DB_TYPE',

	'setup_license_key' => '$SUGAR_LICENSE',
	'setup_system_name' => 'SugarCRM',
	'setup_site_url' => '$url',
	'demoData' => '$DEMO_DATA',
	);
	" > $sugar_si

	echo "Configuration summary:"
	echo "=============================="
	echo "Database type: $SUGAR_DB_TYPE"
	echo "Database host: $db_host"
	echo "Database name: $db_name"
	echo "Database user(admin): $dbuser"
	echo "Setup URL: $url"
	echo "Elastic host: $ELASTIC_HOST"
	echo "Elastic port: $ELASTIC_PORT"

}

#Waits for mysql to start
wait_for_mysql(){
	echo -n "Checking for MYSQL server: $MYSQL_HOST"
	while ! mysqladmin ping -h "$MYSQL_HOST" --silent >/dev/null 2>&1; do
		echo -n "."
		sleep 1
	done
	echo
	echo "MYSQL server is seems ok: $MYSQL_HOST"
}

#Waits for oracle to start
wait_for_oracle(){
	echo -n "Checking for Oracle server: $ORACLE_HOST"
	connection="$DB_USER/$DB_PASS@//$ORACLE_HOST:$ORACLE_PORT/$ORACLE_SERVICE"
	db_ok=1
	n_att=1
	while [ $db_ok = 1 ]; 
	do
		echo -n "."
		n_att=$((n_att+1))
		retval=`sqlplus -silent $connection <<EOF
		SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
		SELECT 'Alive' FROM dual;
		EXIT;
		EOF` || true
		if [ "$retval" = "Alive" ]; then
			db_ok=0
		fi
		sleep 5
		if [ $n_att -gt 10 ]; then 
			echo "FAIL"
			echo "WARNING: Cannot connect to Oracle after 10 attempts"
			echo "Raw sqlplus output is: $retval"
			break
		fi
	done
	echo
	echo "Oracle server is ready:  $ORACLE_HOST"
}

#Silent installation of SugarCRM
sugar_install(){
	#$1 - Sugar installation ZIP file
	sugar_zip=$1

	#root folder name inside a zip archive without trailing slashes
	sugar_root=`unzip -qql $sugar_zip | head -n1 | tr -s ' '| cut -d' ' -f5- | sed 's/\/$//' `
	echo -n "About to unzip installation files... "
	unzip -qq -o $sugar_zip -d $SUGAR_HOME
	echo "done"
	echo "Making silent installl configuration for: $SUGAR_DB_TYPE"
	make_install_configs $sugar_root
	install_url="http://localhost/$SUGAR_BASE/$sugar_root/install.php?goto=SilentInstall&cli=true"
	chown -R $APACHE_USER:$APACHE_GROUP $SUGAR_HOME/$sugar_root
	chmod 777 $SUGAR_HOME/$sugar_root

	echo "Running silent installation of:  $sugar_root"
	result_html=$(curl -XGET $install_url 2>/dev/null)
	if [[ $result_html == *\<bottle\>Success\!\</bottle\>* ]]; then
		echo "$sugar_root has been installed sucessfully, please check /tmp/${sugar_root}_intsall_log.html for details"
	else
		echo "$sugar_root Installation FAILED, please check /tmp/${sugar_root}_intsall_log.html for details"
	fi
	echo $result_html > /tmp/${sugar_root}_intsall_log.html
	mv ${sugar_zip} ${sugar_zip}.processed
}

run_init_scripts(){
	exec="Processing data in: /sugar.d/"
	for f in /sugar.d/*; do
		case $f in
			*.zip)
				echo "Potential sugar installation found: $f"
				echo "Will try to intsall bundle automatically"
				sugar_install $f
				;;
			*.sh)
				echo "Executing shell script $f"
				source $f || true
				;;
			*)
				echo "Ignoring $f"
				;;
		esac
	done
}

#Patch configs to reflect VIRTUAL_HOST variable settings
patch_configs(){
	vh=${SUGAR_HOST:-${VIRTUAL_HOST:-localhost}}
	if [ $vh == "localhost" ]; then
		echo "No virtual hosts are defined with SUGAR_HOST or VIRTUAL_HOST"
	else
		echo "About to set virtual host to $vh"
		for d in $(ls -d $SUGAR_HOME/*/); do

			conf=${d}/config.php

			if [[ -r $conf && -w $conf ]]; then
				cp $conf ${conf}.vh
				sed -i s@http://localhost@http://$vh@g $conf
			fi

		done 
	fi
}

startup_http(){
	service apache2 start
}


shutdown_http(){
	restore_configs || true	
	service apache2 stop || true
	exit 0
}

restore_configs(){
	for d in $(ls -d $SUGAR_HOME/*/); do

		conf=${d}/config.php.vh

		if [ -r $conf  ]; then
			cp $conf ${d}/config.php
			rm -f $conf
		fi

	done
}


setup_redis(){

	if [[ -n $REDIS_HOST && -n $REDIS_PORT ]]; then	

		for d in $(ls -d $SUGAR_HOME/*/); do
			conf_ovr=${d}/config_override.php
			touch $conf_ovr
			if [ ! -s $conf_ovr ]; then
				echo "<?php" > $conf_ovr
			fi
			echo "\$sugar_config['external_cache']['redis']['host'] = '$REDIS_HOST';" >> $conf_ovr
			echo "\$sugar_config['external_cache']['redis']['port'] = '$REDIS_PORT';" >> $conf_ovr     
		done

	fi
}


case "$1" in
	'')
		make_tns && echo "tnsnames.ora has been created"
		patch_phpini && echo "PHP settings applied sucessfully"
		make_override && echo "Configuring apache permissions"
		echo "<?php echo phpinfo() ?>" > $SUGAR_HOME/info.php
		chown -R $APACHE_USER:$APACHE_GROUP /var/www
		startup_http
		echo "HTTP server is ready"
		run_init_scripts
		patch_configs
		setup_redis
		echo "All done, image is ready to use"
		while [ "$END" == '' ]; do
			sleep 1
			trap "shutdown_http" INT TERM
		done
		;;
	*)
		echo "Running wild. Run entrypoint.sh if required"
		$1
		;;
esac
