chef-bootstrap
==============

Get's you up and running with chef-solo with a base chef project in addition to a capistrano remote deployment

intalling
==============

To create your own chef repository, clone the bootstrap project, and call it whatever you like.

```
git clone git://github.com/aforward/chef-bootstrap.git myrepo
```

Next, you will need to add your public key (for access to your remote machine).  Your public key name might differ.

```
cp ~/.ssh/id_dsa.pub ./bootstrap/root_authorized_keys
```

Make sure you have ruby installed, and bundler available

```
gem install bundler
```

Install the necessarily gems

```
bundle install
```

deploying
==============

The basic deployment script is:

```
./deploy <dna> <ip or domain name> <bootstrap|solo|resolo>
```

For, example the first time (or if you upgrade chef / ohai) you deploy to your server

```
./deploy bare 192.168.1.1 bootstrap
```

And, subsequent times you can simply resolo (which is slightly faster)

```
./deploy bare 192.168.1.1 resolo
```

The output will look similar to

```
Andrews-MacBook-Pro:chef-bootstrap aforward$ ./deploy bare 192.168.1.1 resolo
USAGE: ./deploy <dna> <ip> <bootstrap|solo|resolo>
>>> Uploading Authorized Keys For Bootstrap
root@192.168.1.1's password: 
root@192.168.1.1's password: 
root_authorized_keys                                                                                                                                                                      100%  624     0.6KB/s   00:00    
>>> Running chef:resolo
  * 2013-06-11 08:24:47 executing `chef:resolo'
  * 2013-06-11 08:24:47 executing `chef:reinstall_chef_repo'
```

And, if things worked, you should be able to see your helloworld script properly deployed on the server.

```
Andrews-MacBook-Pro:~ aforward$ ssh root@192.168.1.1
root@192.168.1.1's password: 
Welcome to Ubuntu 12.04 LTS (GNU/Linux 3.2.0-23-virtual x86_64)

 * Documentation:  https://help.ubuntu.com/
Last login: Tue Jun 11 10:55:30 2013 from cpeb8c75dc84edd-cm00222d74ef9b.cpe.net.cable.rogers.com
root@a4word:~# /root/helloworld 
HELLO WORLD
```

Now go forth and http://www.opscode.com/chef/





