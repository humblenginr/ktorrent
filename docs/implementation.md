# Parsing the torrent metainfo file

We assume that we somehow get the .torrent file. 
The .torrent file, also known as the metainfo file, is a bencoded dictionary with the following structure:

```json
{
    "info" : {
        "piece_length" :  "_number of bytes in each piece_",
        "pieces" : ""_string concatenation of the hashes (20 byte SHA1 hash) of all pieces_",
        "name" : "_name of the file being downloaded (this is what will be shown as the name of the file after downloading)_",
        "length" : "_length of the file in bytes_",

    },
    "announce" : "_The tracker URL_"
}
```
(> NOTE: The above example is for a single file torrent)

The client first decodes this metainfo file to get all the required information.

# Getting the list of peers

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

# Peer - Peer communication

_file_ - file we are downloading through torrent
_piece_ - each _file_ is divided into multiple parts and each part is called _piece_

Once we get the list of peers, we can start downloading the _file_ from them. Each peer will have different _pieces_. 
We have to use the Peer Wire Protocol (TCP) to communicate with the peers and obtain file pieces from them. 

The protocol works like this:
1. First we have to establish a TCP connection with a peer [x]
2. Send a `handshake` message which is used to let the peer know what file pieces we are interested in (using the `info_hash`) and some metadata info. [x]
If the peer has the file pieces we need, it will send a similar response, else it will drop the connection.
3. The peer will send the information about the pieces it has using `have` or `bitfield` messages.
4. The peer might send the `choke` message. If not, then the next step is for us to send `interested` message, and we hope for the peer to send `unchoke` message. 
For each connection with the peer, we have to maintain a state like this: {am_choking, am_interested, peer_choking, peer_interested}.
5. Once we have `am_interested = 1` and `peer_choking = 0`, then we can start sending `request` messages to download the pieces of the file

(refer to Peer Wire Protocol section in https://wiki.theory.org/BitTorrentSpecification#Tracker_HTTP.2FHTTPS_Protocol for implementation details and message descriptions)


Now that we have completed the handshake, we have to start asking for torrent pieces. 
By looking at the tracker file, it has the `piece_length` and a field called `pieces`
`pieces` is the string concatenation of all 20 byte SHA1 hash values of the pieces. We have to use this to verify that the 
piece this client has downloaded is valid. 
We basically have a bunch of pieces we need to download. Let us first establish a client that can successfully download one single piece.

We basically should have a stream listening on the file descriptor, and whenever some message is being sent, it has to be handled. 
Once we establish handshake, I do not know exactly when we will receive this, but we will receive this bitfield message from the peer indicating
what pieces i can request.
Therefore, it is important to constantly keep listening on the fd to interpret the messages.

once a piece has been downloaded from a peer and verified, a `have` message should be sent to the peer

1.Download a piece from a client and verify it with the hash.
First thing that I have to send after establishing handshake is that i am interested in a piece
After we send the interested message, we basically have to wait for the peer to send an `unchoke` message.
Once we are unchoked, we can send request messages requesting for a particular piece


