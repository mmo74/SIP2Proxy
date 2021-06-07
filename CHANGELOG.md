# Changelog
(Latest changes on top of the file)

## 20210329 - mmo
- Listen on all interfaces for incomming connections
- changed CL-mapping
- dropped some useless lines
- dropped Proc:Deamon and use functions from NET:Server to run as daemon

## 20210323 - mmo
- switched from IO::Socket to Net::Server::Fork for the main loop
- this makes the client handling much easier

## 20210318 - mmo
- first running version
- I hope all functions are present and no mayor bugs ...

## 20210312 - mmo
- start project
