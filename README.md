## jenkins 镜像

service port：8010
slave pot: 50000

VOLIME: /devopsdata
JENKINS_HOME: /devopsdata/jenkins

run:
```
docker run -d -p 8010:8010 -p 50000:50000 -v /mypath:/devopsdata --name jenkins zooltech/jenkins
```

share maven repository:
```
docker run -d -p 8010:8010 -p 50000:50000 -v /mypath:/devopsdata -v /mypath/mvnrepo:/devopsdata/jenkins/.m2/repository --name jenkins zooltech/jenkins
```
