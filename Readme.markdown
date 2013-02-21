# What is it ?

Here are [capistrano](https://github.com/capistrano/capistrano/wiki) extensions to be used with [master-chef](https://github.com/octo-technology/master-chef)

# How to use it

* Add ``master-cap`` to your Gemfile
* Load ``master-cap`` in your Capfile: ``require 'master-cap/topology-directory.rb'``
* Create a subdirectory named ``topology``, and add your toplogy YAML files into
* Enjoy :)

# Topology file

Example of a topology file: ``integ.yml``

```yml
:topology:
  :app:
    :hostname: my_app_server.mydomain.net
    :type: linux_chef
    :roles:
      - app_server
  :db:
    :hostname: db_server.mydomain.net
    :type: linux_chef
    :roles:
      - db_server
  :redis:
    :hostname: redise.mydomain.net
    :type: linux_chef
    :roles:
      - redis_server
:cap_override:
  :my_specific_cap_param: 'toto'
:default_role_list:
  - base
```

# Capistrano commands

## Node selection

* ``cap integ show``
* ``cap app-integ show``
* ``cap integ_db_server show``

## SSH command

* ``cap integ check``: try to connect on each nodes with ssh
* ``cap integ ssh_cmd -s cmd=uname``: exec ``uname``command on each nodes

# License

Copyright 2012 Bertrand Paquet

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.