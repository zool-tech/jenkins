# JENKINS openjdk-8. Update center use mirror: https://mirrors.tuna.tsinghua.edu.cn/
FROM debian:buster-slim

MAINTAINER shopboss@qq.com

ENV	LANG=C.UTF-8 \
	JAVA_HOME=/opt/java/openjdk-8 \
	APPDATA_DIR=/devopsdata
ENV	JENKINS_HOME=${APPDATA_DIR}/jenkins \
	JENKINS_HTTP_PORT=8010 \
	JENKINS_SLAVE_AGENT_PORT=50000 \
	PATH=${JAVA_HOME}/bin:${PATH}

VOLUME	["${APPDATA_DIR}"]

RUN	set -eux;\
	DEVOPS_GROUP=devops;\
	DEVOPS_GID=60000;\
	START_SCRIPT=/opt/startSrvs.sh;\
# java install params
	JAVA_DOWNLOAD_URL=https://github.com/AdoptOpenJDK/openjdk8-upstream-binaries/releases/download/jdk8u252-b09/OpenJDK8U-jdk_x64_linux_8u252b09.tar.gz;\
# jinkins install params
	JENKINS_VERSION=2.222.1;\
	JENKINS_USER=jenkins;\
	JENKINS_UID=60001;\
	JENKINS_INSTALL_DIR=/opt/jenkins;\
	JENKINS_DOWNLOAD_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war;\
# INIT
	mkdir -p "${JAVA_HOME}" "${JENKINS_INSTALL_DIR}";\
	apt-get -q update && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends ca-certificates p11-kit busybox fontconfig && rm -rf /var/lib/apt/lists/*;\
# busybox soft link
	for cmdStr in free ip less nc netstat nslookup ping ps tail top tracerout vi watch wget; do if [ ! -f "/bin/${cmdStr}" ]; then ln -s busybox /bin/${cmdStr}; fi; done;\
# INSTALL OPENJDK
	wget -q -O openjdk.tgz ${JAVA_DOWNLOAD_URL};\
	tar --extract --file openjdk.tgz --directory "${JAVA_HOME}" --strip-components 1;\
	rm openjdk.tgz "${JAVA_HOME}/src.zip" && rm -rf "${JAVA_HOME}/demo" "${JAVA_HOME}/sample";\
# update "cacerts" bundle to use Debian's CA certificate
	mkdir -p /etc/ca-certificates/update.d;\
	{\
		echo '#!/usr/bin/env bash';\
		echo 'set -euo pipefail';\
		echo 'cerfile=${JAVA_HOME}/jre/lib/security/cacerts';\
		echo 'if [ ! -f "${cerfile}" ]; then echo >&2 "error: failed to find cacerts file in ${JAVA_HOME}"; exit 1; fi';\
		echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "${cerfile}"';\
	} > /etc/ca-certificates/update.d/docker-openjdk;\
	chmod +x /etc/ca-certificates/update.d/docker-openjdk;\
	/etc/ca-certificates/update.d/docker-openjdk;\
# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
	find "${JAVA_HOME}/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf;\
	ldconfig;\
# INSTALL JENKINS
	wget -q -O jenkins.war ${JENKINS_DOWNLOAD_URL} \
	&& busybox unzip -d ${JENKINS_INSTALL_DIR} jenkins.war \
	&& rm -f jenkins.war;\
	wget -q -t 5 -O ${JENKINS_INSTALL_DIR}/WEB-INF/update-center-rootCAs/mirror-adapter.crt --no-check-certificate https://raw.githubusercontent.com/jenkins-zh/mirror-adapter/master/rootCA/mirror-adapter.crt;\
# groups & users
	groupadd -g ${DEVOPS_GID} ${DEVOPS_GROUP};\
	useradd -d ${JENKINS_HOME} -g ${DEVOPS_GROUP} -u ${JENKINS_UID} ${JENKINS_USER} && chown -R ${JENKINS_USER}:${DEVOPS_GROUP} ${JENKINS_INSTALL_DIR};\
# script for start all
	{\
		echo "#!/usr/bin/env bash\nset -uo pipefail";\
		echo "if [ ! -d ${JENKINS_HOME} ]; then mkdir -p ${JENKINS_HOME}/logs;fi;\nif [ ! \`ls -la ${JENKINS_HOME} | sed -n '2p' | awk -F ' ' '{print \$3}'\` = '${JENKINS_USER}' ]; then chown -R ${JENKINS_UID}:${DEVOPS_GID} ${JENKINS_HOME};fi";\
		echo "runuser ${JENKINS_USER} -g ${DEVOPS_GROUP} -c '${JAVA_HOME}/bin/java -Djava.awt.headless=true -Dhudson.model.UpdateCenter.updateCenterUrl=https://updates.jenkins-zh.cn/ -jar ${JENKINS_INSTALL_DIR}/winstone.jar --webroot=${JENKINS_INSTALL_DIR} --httpPort=${JENKINS_HTTP_PORT}'";\
	} > ${START_SCRIPT} && chmod u+x ${START_SCRIPT}

EXPOSE	${JENKINS_HTTP_PORT} ${JENKINS_SLAVE_AGENT_PORT}

ENTRYPOINT	["/opt/startSrvs.sh"]
