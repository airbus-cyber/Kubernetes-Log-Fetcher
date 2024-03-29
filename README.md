# Kubernetes log fetcher

The purpose of this software is to collect logs from a Kubernetes cluster.

Kubernetes log fetcher runs on docker. The directory "cloud-module" contains the Dockerfile to build the log collector container (which runs get_logs.sh). The script writes the logs in files. An utilisation of it could be to send those logs to Graylog through rsyslog.

## License

Kubernetes log fetcher

Copyright (C) 2023 Airbus CyberSecurity SAS

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

### Third-party software usage

This program uses the following software to run:

| Software | Version | Copyright | License |
|-|-|-|-|
| Bitnami package for Kubectl | 1^ | 2023 VMware, Inc. | Apache-2.0 |
| jq | 1^ | 2012 Stephen Dolan | MIT |
| Kubectl | 1^ | 2023 Kubernetes | Apache-2.0 |

## Log Format

Predicting what the exact log format will be once we retrieve logs from a kubernetes cluster is not easy. The log format depends mainly on the applications running in that cluster. Every editor has different logic on how they represent the logs of their applications. 
However, there are some cases where we can understand the logs without knowing the format beforehand :
- When the logs are in json format, we have both the fields and the values, and this is easy de parse so it makes the format intelligible for us. This is the case for the events from kubernetes that we are monitoring (kubectl get events)
- On every cluster, we have some containers that are always here. In fact, every kubernetes distribution follows some rules. This is why they all have containers for API Server, Scheduler, Controller Manager, and etcd. If we study there log format, we know that on every distribution, we will have roughly the same logs even if some have enhanced capabilities.

On every container log, we have a header containing useful information to determine where the log comes from
[resource_type/pod_name/container_name] <TIMESTAMP> <MESSAGE>

For the Controller manager : 
[pod/cloud-controller-manager-cloud-cluster/cloud-controller-manager] 2023-05-31T06:48:34.354618248Z W0531 06:48:34.354571       1 controllermanager.go:288] "service" is disabled

For etcd :
[pod/etcd-cloud-cluster/etcd] 2023-06-23T12:51:06.225562796Z {"level":"info","ts":"2023-06-23T12:51:06.225Z","caller":"fileutil/purge.go:77","msg":"purged","path":"/var/lib/rancher/rke2/server/db/etcd/member/snap/0000000000000003-0000000000dc5c4e.snap"}
In this case, the message is in json format so we will be able to parse it easily.

For apiserver :
[pod/kube-apiserver-cloud-cluster/kube-apiserver] 2023-06-23T12:52:15.539558976Z W0623 12:52:15.539458       1 watcher.go:229] watch chan error: etcdserver: mvcc: required revision has been compacted

For the scheduler :
[pod/kube-scheduler-cloud-cluster/kube-scheduler] 2023-05-31T06:47:57.154583108Z I0531 06:47:57.154215       1 leaderelection.go:258] successfully acquired lease kube-system/kube-scheduler
