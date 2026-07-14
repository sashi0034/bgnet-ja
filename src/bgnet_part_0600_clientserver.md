# クライアント・サーバーの背景

[i[Client/Server]<]

世の中はクライアント・サーバーだ、ベイベー。ネットワーク上のほとんどすべてが、クライアントプロセスとサーバープロセスが互いに会話する形になっている。例えば `telnet` だ。telnet（クライアント）でリモートホストの 23 番ポートに接続すると、そのホスト上のプログラム（`telnetd`、サーバー）が起動する。入ってきた telnet 接続を処理し、ログインプロンプトを出してくれる、といった具合だ。

![クライアント・サーバー間のやりとり。](cs.pdf "[クライアント・サーバー相互作用図]")

クライアントとサーバー間の情報のやりとりは、上の図にまとめてある。

クライアント・サーバーのペアは `SOCK_STREAM` でも `SOCK_DGRAM` でも何でも話せる（同じものを話していれば）。クライアント・サーバーペアの例としては `telnet`/`telnetd`、`ftp`/`ftpd`、`Firefox`/`Apache` などがある。`ftp` を使うたびに、あなたにサービスを提供するリモートプログラム `ftpd` がある。

多くの場合、1 台のマシンにはサーバーは 1 つだけで、[i[`fork()` function]] `fork()` を使って複数のクライアントを処理する。基本的な流れはこうだ：サーバーは接続を待ち、`accept()` し、処理用に子プロセスを `fork()` する。次のセクションのサンプルサーバーがまさにそうしている。


## シンプルなストリームサーバー

[i[Server-->stream]<]

このサーバーがやることは、ストリーム接続越しに文字列 "`Hello, world!`" を送るだけだ。テストするには、あるウィンドウでサーバーを動かし、別のウィンドウから telnet すればいい：

```
$ telnet remotehostname 3490
```

`remotehostname` はサーバーを動かしているマシン名だ。

[flx[サーバーのコード|server.c]]:

```{.c .numberLines}
/*
** server.c -- a stream socket server demo
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/wait.h>
#include <signal.h>

#define PORT "3490"  // the port users will be connecting to

#define BACKLOG 10   // how many pending connections queue will hold

void sigchld_handler(int s)
{
    (void)s; // quiet unused variable warning

    // waitpid() might overwrite errno, so we save and restore it:
    int saved_errno = errno;

    while(waitpid(-1, NULL, WNOHANG) > 0);

    errno = saved_errno;
}


// get sockaddr, IPv4 or IPv6:
void *get_in_addr(struct sockaddr *sa)
{
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }

    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

int main(void)
{
    // listen on sock_fd, new connection on new_fd
    int sockfd, new_fd;
    struct addrinfo hints, *servinfo, *p;
    struct sockaddr_storage their_addr; // connector's address info
    socklen_t sin_size;
    struct sigaction sa;
    int yes=1;
    char s[INET6_ADDRSTRLEN];
    int rv;

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE; // use my IP

    if ((rv = getaddrinfo(NULL, PORT, &hints, &servinfo)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return 1;
    }

    // loop through all the results and bind to the first we can
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol)) == -1) {
            perror("server: socket");
            continue;
        }

        if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes,
                sizeof(int)) == -1) {
            perror("setsockopt");
            exit(1);
        }

        if (bind(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            close(sockfd);
            perror("server: bind");
            continue;
        }

        break;
    }

    freeaddrinfo(servinfo); // all done with this structure

    if (p == NULL)  {
        fprintf(stderr, "server: failed to bind\n");
        exit(1);
    }

    if (listen(sockfd, BACKLOG) == -1) {
        perror("listen");
        exit(1);
    }

    sa.sa_handler = sigchld_handler; // reap all dead processes
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1) {
        perror("sigaction");
        exit(1);
    }

    printf("server: waiting for connections...\n");

    while(1) {  // main accept() loop
        sin_size = sizeof their_addr;
        new_fd = accept(sockfd, (struct sockaddr *)&their_addr,
            &sin_size);
        if (new_fd == -1) {
            perror("accept");
            continue;
        }

        inet_ntop(their_addr.ss_family,
            get_in_addr((struct sockaddr *)&their_addr),
            s, sizeof s);
        printf("server: got connection from %s\n", s);

        if (!fork()) { // this is the child process
            close(sockfd); // child doesn't need the listener
            if (send(new_fd, "Hello, world!", 13, 0) == -1)
                perror("send");
            close(new_fd);
            exit(0);
        }
        close(new_fd);  // parent doesn't need this
    }

    return 0;
}
```

気になる人のために言うと、構文のわかりやすさのため（と思う）コードは 1 つの大きな `main()` にまとめてある。気に入らなければ好きなように小さな関数に分割してくれ。

（あと、この [i[`sigaction()` function]] `sigaction()` の話は初めてかも——大丈夫。ここにあるコードは、`fork()` した子プロセスが終了したときに現れる [i[Zombie process]] ゾンビプロセスを回収するためのものだ。ゾンビを大量に作って回収しないと、システム管理者が機嫌を悪くするぞ。）

このサーバーからデータを受け取るには、次のセクションのクライアントを使えばいい。

[i[Server-->stream]>]

## シンプルなストリームクライアント

[i[Client-->stream]<]

こっちはサーバーよりさらに簡単だ。このクライアントがやることは、コマンドラインで指定したホストの 3490 番ポートに接続し、サーバーが送ってくる文字列を受け取るだけだ。

[flx[クライアントのソース|client.c]]:

```{.c .numberLines}
/*
** client.c -- a stream socket client demo
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <netdb.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>

#include <arpa/inet.h>

#define PORT "3490" // the port client will be connecting to 

#define MAXDATASIZE 100 // max number of bytes we can get at once 

// get sockaddr, IPv4 or IPv6:
void *get_in_addr(struct sockaddr *sa)
{
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }

    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

int main(int argc, char *argv[])
{
    int sockfd, numbytes;  
    char buf[MAXDATASIZE];
    struct addrinfo hints, *servinfo, *p;
    int rv;
    char s[INET6_ADDRSTRLEN];

    if (argc != 2) {
        fprintf(stderr,"usage: client hostname\n");
        exit(1);
    }

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    if ((rv = getaddrinfo(argv[1], PORT, &hints, &servinfo)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return 1;
    }

    // loop through all the results and connect to the first we can
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol)) == -1) {
            perror("client: socket");
            continue;
        }

        inet_ntop(p->ai_family,
            get_in_addr((struct sockaddr *)p->ai_addr),
            s, sizeof s);
        printf("client: attempting connection to %s\n", s);

        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            perror("client: connect");
            close(sockfd);
            continue;
        }

        break;
    }

    if (p == NULL) {
        fprintf(stderr, "client: failed to connect\n");
        return 2;
    }

    inet_ntop(p->ai_family,
            get_in_addr((struct sockaddr *)p->ai_addr),
            s, sizeof s);
    printf("client: connected to %s\n", s);

    freeaddrinfo(servinfo); // all done with this structure

    if ((numbytes = recv(sockfd, buf, MAXDATASIZE-1, 0)) == -1) {
        perror("recv");
        exit(1);
    }

    buf[numbytes] = '\0';

    printf("client: received '%s'\n",buf);

    close(sockfd);

    return 0;
}
```

サーバーを動かす前にクライアントを実行すると、`connect()` は [i[Connection refused]] "Connection refused" を返す。とても便利だ。

[i[Client-->stream]>]

## データグラムソケット {#datagram}

[i[Server-->datagram]<]

`sendto()` と `recvfrom()` の説明で UDP データグラムソケットの基本はすでに触れたので、ここではサンプルプログラム `talker.c` と `listener.c` を 2 つ提示するだけにする。

`listener` はマシン上で 4950 番ポートへの着信パケットを待ち、`talker` は指定マシンのそのポートに、コマンドラインでユーザーが入力した内容を含むパケットを送る。

データグラムソケットはコネクションレスで、成功するかどうか気にせずパケットを宇宙に放り投げるので、クライアントとサーバーには明示的に IPv6 を使わせる。こうすれば、サーバーが IPv6 で待ち受けているのにクライアントが IPv4 で送る、という不一致を避けられる（データは届かない）。接続型 TCP ストリームソケットの世界では不一致があっても、`connect()` のエラーで別のアドレスファミリーを再試行できる。

[flx[`listener.c` のソース|listener.c]] は次のとおり：

```{.c .numberLines}
/*
** listener.c -- a datagram sockets "server" demo
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#define MYPORT "4950"    // the port users will be connecting to

#define MAXBUFLEN 100

// get sockaddr, IPv4 or IPv6:
void *get_in_addr(struct sockaddr *sa)
{
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }

    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

int main(void)
{
    int sockfd;
    struct addrinfo hints, *servinfo, *p;
    int rv;
    int numbytes;
    struct sockaddr_storage their_addr;
    char buf[MAXBUFLEN];
    socklen_t addr_len;
    char s[INET6_ADDRSTRLEN];

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET6; // or set to AF_INET to use IPv4
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_flags = AI_PASSIVE; // use my IP

    if ((rv = getaddrinfo(NULL, MYPORT, &hints, &servinfo)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return 1;
    }

    // loop through all the results and bind to the first we can
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol)) == -1) {
            perror("listener: socket");
            continue;
        }

        if (bind(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            close(sockfd);
            perror("listener: bind");
            continue;
        }

        break;
    }

    if (p == NULL) {
        fprintf(stderr, "listener: failed to bind socket\n");
        return 2;
    }

    freeaddrinfo(servinfo);

    printf("listener: waiting to recvfrom...\n");

    addr_len = sizeof their_addr;
    if ((numbytes = recvfrom(sockfd, buf, MAXBUFLEN-1 , 0,
        (struct sockaddr *)&their_addr, &addr_len)) == -1) {
        perror("recvfrom");
        exit(1);
    }

    printf("listener: got packet from %s\n",
        inet_ntop(their_addr.ss_family,
            get_in_addr((struct sockaddr *)&their_addr),
            s, sizeof s));
    printf("listener: packet is %d bytes long\n", numbytes);
    buf[numbytes] = '\0';
    printf("listener: packet contains \"%s\"\n", buf);

    close(sockfd);

    return 0;
}
```

`getaddrinfo()` の呼び出しで、ついに `SOCK_DGRAM` を使っていることに注目。`listen()` や `accept()` も不要だ。非接続データグラムソケットの利点のひとつだ！

[i[Server-->datagram]>]

[i[Client-->datagram]<]

次は [flx[`talker.c` のソース|talker.c]]：

```{.c .numberLines}
/*
** talker.c -- a datagram "client" demo
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#define SERVERPORT "4950"   // the port users will be connecting to

int main(int argc, char *argv[])
{
    int sockfd;
    struct addrinfo hints, *servinfo, *p;
    int rv;
    int numbytes;

    if (argc != 3) {
        fprintf(stderr,"usage: talker hostname message\n");
        exit(1);
    }

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET6; // set to AF_INET to use IPv4
    hints.ai_socktype = SOCK_DGRAM;

    rv = getaddrinfo(argv[1], SERVERPORT, &hints, &servinfo);
    if (rv != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return 1;
    }

    // loop through all the results and make a socket
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol)) == -1) {
            perror("talker: socket");
            continue;
        }

        break;
    }

    if (p == NULL) {
        fprintf(stderr, "talker: failed to create socket\n");
        return 2;
    }

    if ((numbytes = sendto(sockfd, argv[2], strlen(argv[2]), 0,
             p->ai_addr, p->ai_addrlen)) == -1) {
        perror("talker: sendto");
        exit(1);
    }

    freeaddrinfo(servinfo);

    printf("talker: sent %d bytes to %s\n", numbytes, argv[1]);
    close(sockfd);

    return 0;
}
```

以上、それだけだ！あるマシンで `listener` を動かし、別のマシンで `talker` を実行しよう。通信するのを見て楽しんでくれ！核家族全員で楽しめる G 指定の興奮だ！

今回はサーバーを動かす必要もない！`talker` だけ実行しても、向こう側に `recvfrom()` で待ち受けている相手がいなければ、パケットはどこかへ消えていくだけだ。覚えておいて：UDP データグラムソケットで送ったデータは届く保証がない！

[i[Client-->datagram]>]

過去何度も触れてきた、もう 1 つの小さな詳細を除けば——[i[`connect()` function-->on datagram sockets]] 接続型データグラムソケットだ。ドキュメントのデータグラムの章なので、ここで話しておく。`talker` が `connect()` を呼び、`listener` のアドレスを指定したとする。その時点から `talker` は `connect()` で指定したアドレスとのみ送受信できる。だから `sendto()` と `recvfrom()` を使う必要はなく、単に `send()` と `recv()` だけでいい。

[i[Client/Server]>]
