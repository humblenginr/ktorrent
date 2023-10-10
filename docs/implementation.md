We assume that we somehow get the .torrent file. 
The .torrent file, also known as the metainfo file, is a bencoded dictionary with the following structure:

```json
{
    "info" : {
        "piece_length" :  _number of bytes in each piece_,
        "pieces" : _string concatenation of the hashes (20 byte SHA1 hash) of all pieces_,
        "name" : _name of the file being downloaded (this is what will be shown as the name of the file after downloading)_,
        "length" : _length of the file in bytes_,

    },
    "announce" : _The tracker URL_
}
```
(> NOTE: The above example is for a single file torrent)

The client first decodes this metainfo file to get all the required information.

There is something called as the Tracker which is just a HTTP/HTTPS server and it is responsible for managing torrents. Once we decode the metainfo file, the 
client will then send a request to the Tracker by using the URL specified in the `announce` field of the metainfo file. 

There are some parameters that the client has to send when sending a request to the tracker:
1. `info_hash` - urlencoded 20 byte SHA1 hash of the _value_ of the _info_ field from the metainfo file 
    This is basically the bencoded _value_ dictionary and this is what the Tracker uses to identify a particular torrent (if it is the one managing it)
2. `peer_id` - urlencoded 20 byte string used as the unique ID for the client
    This is how the Tracker identifies the peers for a particular torrent
3. `port` - the port number the client is listening on
4. `uploaded` - total number of bytes uploaded by the client for this torrent
5. `downloaded` - total number of bytes downloaded by the client for this torrent
6. `left` - total number of bytes left to be downloaded by the client for this torrent to be complete/finished
7. `event` - specifies what event is being performed
    This can be `started`, `stopped`, or `completed`. For the first request, it should be `started`. This can also be not specified or an empty string. If it is not specified,
    then this will be considered as the request being sent at regular intervals 
8. `compact` - just keep it as 0 for now (some trackers might just refuse requests with compact as 0, so need to be aware of that as well)
9. `no_peer_id` - it ignores the peer id field in the peers list being sent by the server

Once the request is sent, the tracker will respond with the list of peers to which the client can connect to, along with some other information such as how many peers are there, 
how many of them are seeders, how many of them are leechers, etc. If there are some errors, then the tracker will respond with the error or warning.

Now we have to see how we can use the list of peers to start downloading the file

For this, we have to first establish a connection with the Tracker. Tracker server can be HTTP(S) or UDP. First we have to find out which protocol is being 
used by the tracker. Then we have to establish a connection with the tracker. Steps to establish the connection varies between HTTP and UDP. 

Since the sample torrent file I have has a UDP tracker, I will first implement for the UDP protocol.

**Implementation for UDP Protocol**

BitTorrent UDP protocol specification - http://bittorrent.org/beps/bep_0015.html

UDP is a binary based protocol, therefore all the numbers being sent over the network has to be in 'Big Endian' byte order.
Unlike the TCP protocol, UDP is unreliable (packets may arrive out of order, appear to have duplicates or disappear without warning). So we have to set
up a retry without timeout flow for UDP connections.

