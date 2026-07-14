# ちょっと進んだテクニック

これらは _本当に_ 高度というわけではないが、これまで扱ってきた基本的なレベルを超えてきている。実際、ここまで来たなら、Unix ネットワークプログラミングの基礎はかなり身についたと言っていいだろう！ おめでとう！

さあ、ソケットについて学びたくなる、もう少しマニアックな領域へ踏み込んでいこう。やってみよう！


## ブロッキング {#blocking}

[i[Blocking]<]

ブロッキング。聞いたことはあるだろう——で、いったい何だ？ 要するに「block」は技術者用語で「sleep（スリープ）」のことだ。上で `listener` を動かしたとき、パケットが届くまでじっとしているのに気づいたかもしれない。起きていることは、`recvfrom()` を呼んだがデータがなく、`recvfrom()` が「ブロック」している（つまりそこでスリープしている）と言われる、ということだ。データが届くまで。

ブロックする関数はたくさんある。`accept()` はブロックする。`recv()` 系は全部ブロックする。できる理由は、許されているからだ。`socket()` で最初にソケット記述子を作ると、カーネルはそれをブロッキングに設定する。[i[Non-blocking sockets]] ブロッキングにしたくないなら、[i[`fcntl()` function]] `fcntl()` を呼ぶ必要がある：

```{.c .numberLines}
#include <unistd.h>
#include <fcntl.h>
.
.
.
sockfd = socket(PF_INET, SOCK_STREAM, 0);
fcntl(sockfd, F_SETFL, O_NONBLOCK);
.
.
. 
```

ソケットをノンブロッキングにすると、事実上ソケットを「ポーリング」して情報を得られる。ノンブロッキングソケットから読もうとしてデータがなければ、ブロックは許されない——`-1` を返し、`errno` は [i[`EAGAIN` macro]] `EAGAIN` か [i[`EWOULDBLOCK` macro]] `EWOULDBLOCK` に設定される。

（待てよ——[i[`EAGAIN` macro]] `EAGAIN` _か_ [i[`EWOULDBLOCK` macro]] `EWOULDBLOCK` が返る？ どっちをチェックする？ 仕様は実際にはシステムがどちらを返すかは指定していないので、移植性のため両方チェックしよう。）

ただし一般に、この種のポーリングは悪い考えだ。ソケットにデータがあるかビジー・ウェイトでループすると、CPU 時間を猛烈に食う。データ待ちをもっとエレガントに調べる方法は、次の [i[`poll()` function]] `poll()` の節にある。

[i[Blocking]>]


## `poll()`——同期 I/O 多重化 {#poll}

[i[poll()]<]

本当にやりたいのは、_たくさんの_ ソケットを一度に監視して、データの準備ができたものだけ処理することだ。そうすれば、読み込み準備ができたソケットを見つけるために、ずっと全部をポーリングし続ける必要がない。

> _注意：接続数が膨大なとき、`poll()` はひどく遅い。そういう状況では、システムで使える最速の方法を選ぼうとする [fl[libevent|https://libevent.org/]] のようなイベントライブラリの方がパフォーマンスが良い。_

ではポーリングを避けるには？ 少し皮肉なことに、`poll()` システムコールを使えばポーリングを避けられる。要するに、面倒な仕事は OS に任せて、どのソケットに読めるデータがあるか教えてもらうだけだ。その間、プロセスはスリープしてシステムリソースを節約できる。

大まかな流れは、監視したいソケット記述子と、どんなイベントを監視するかの情報を持つ `struct pollfd` の配列を用意することだ。OS は `poll()` 呼び出しでブロックし、それらのイベントのいずれか（例：「ソケット読み込み準備完了！」）か、ユーザー指定のタイムアウトが起きるまで待つ。

便利なことに、`listen()` しているソケットは、新しい着信接続が `accept()` できる状態になると「読み込み準備完了」を返す。

おしゃべりはここまで。使い方は？

``` {.c}
#include <poll.h>

int poll(struct pollfd fds[], nfds_t nfds, int timeout);
```

`fds` は情報の配列（どのソケットを何のために監視するか）、`nfds` は配列の要素数、`timeout` はミリ秒単位のタイムアウトだ。イベントが起きた配列要素の数を返す。

その `struct` を見てみよう：

[i[`struct pollfd` type]]

``` {.c}
struct pollfd {
    int fd;         // the socket descriptor
    short events;   // bitmap of events we're interested in
    short revents;  // on return, bitmap of events that occurred
};
```

この配列を用意し、各要素の `fd` フィールドに監視したいソケット記述子を入れる。そして `events` フィールドに興味のあるイベントの種類を設定する。

`events` フィールドは次のビットごとの OR だ：

| Macro     | 説明                                                         |
|-----------|--------------------------------------------------------------|
| `POLLIN`  | このソケットで `recv()` できるデータが用意されたら知らせて。 |
| `POLLOUT` | このソケットへブロックせずに `send()` できるようになったら知らせて。 |
| `POLLHUP` | リモートが接続を閉じたら知らせて。                           |

`struct pollfd` の配列ができたら、それを `poll()` に渡し、配列のサイズとミリ秒単位のタイムアウトも渡す。（負のタイムアウトで永遠に待つこともできる。）

`poll()` が戻ったら、`revents` フィールドを見て `POLLIN` や `POLLOUT` がセットされているか確認し、そのイベントが起きたことを知る。

（`poll()` 呼び出しでできることは実はもっとある。詳細は下の [`poll()` man ページ](#pollman) を参照。）

標準入力からデータが読めるようになるまで 2.5 秒待つ [flx[例|poll.c]] だ。つまり `RETURN` を押したとき：

``` {.c .numberLines}
#include <stdio.h>
#include <poll.h>

int main(void)
{
    struct pollfd pfds[1]; // More if you want to monitor more

    pfds[0].fd = 0;          // Standard input
    pfds[0].events = POLLIN; // Tell me when ready to read

    // If you needed to monitor other things, as well:
    //pfds[1].fd = some_socket; // Some socket descriptor
    //pfds[1].events = POLLIN;  // Tell me when ready to read

    printf("Hit RETURN or wait 2.5 seconds for timeout\n");

    int num_events = poll(pfds, 1, 2500); // 2.5 second timeout

    if (num_events == 0) {
        printf("Poll timed out!\n");
    } else {
        int pollin_happened = pfds[0].revents & POLLIN;

        if (pollin_happened) {
            printf("File descriptor %d is ready to read\n",
                    pfds[0].fd);
        } else {
            printf("Unexpected event occurred: %d\n",
                    pfds[0].revents);
        }
    }

    return 0;
}
```

また `poll()` は、`pfds` 配列のうちイベントが起きた要素の _数_ を返すことに注意。配列の _どの_ 要素かは教えてくれない（それは自分でスキャンする必要がある）が、`revents` がゼロでないエントリがいくつあるかは教えてくれる（だからその数だけ見つけたらスキャンを止められる）。

ここで疑問が出るかもしれない：`poll()` に渡すセットに新しいファイル記述子を追加するには？ 必要な分だけ配列に十分なスペースがあることを確認するか、必要に応じて `realloc()` で増やせばいい。

セットから項目を削除するには？ 配列の最後の要素を削除したい要素の上にコピーする。そして `poll()` に渡すカウントを 1 つ減らす。別の方法として、任意の `fd` フィールドを負の数にすると `poll()` は無視する。

これを全部まとめて、`telnet` で接続できるチャットサーバーにするには？

リスナーソケットを起動し、`poll()` するファイル記述子のセットに追加する。（着信接続があると読み込み準備完了になる。）

新しい接続を `struct pollfd` 配列に追加する。スペースが足りなくなったら動的に拡張する。

接続が閉じられたら配列から削除する。

接続が読み込み準備完了になったらデータを読み、他の接続すべてに送って、他のユーザーが何を打ったか見えるようにする。

では [flx[この poll サーバー|pollserver.c]] を試してみよう。1 つのウィンドウで動かし、他の複数のターミナルウィンドウから `telnet localhost 9034` する。1 つのウィンドウで打ったものが、他のウィンドウにも（`RETURN` を押したあと）見えるはずだ。

それだけでなく、`CTRL-]` を押して `quit` と打って `telnet` を終了すると、サーバーは切断を検出してファイル記述子の配列から削除するはずだ。

``` {.c .numberLines}
/*
** pollserver.c -- a cheezy multiperson chat server
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <poll.h>

#define PORT "9034"   // Port we're listening on

/*
 * Convert socket to IP address string.
 * addr: struct sockaddr_in or struct sockaddr_in6
 */
const char *inet_ntop2(void *addr, char *buf, size_t size)
{
    struct sockaddr_storage *sas = addr;
    struct sockaddr_in *sa4;
    struct sockaddr_in6 *sa6;
    void *src;

    switch (sas->ss_family) {
        case AF_INET:
            sa4 = addr;
            src = &(sa4->sin_addr);
            break;
        case AF_INET6:
            sa6 = addr;
            src = &(sa6->sin6_addr);
            break;
        default:
            return NULL;
    }

    return inet_ntop(sas->ss_family, src, buf, size);
}

/*
 * Return a listening socket.
 */
int get_listener_socket(void)
{
    int listener;     // Listening socket descriptor
    int yes=1;        // For setsockopt() SO_REUSEADDR, below
    int rv;

    struct addrinfo hints, *ai, *p;

    // Get us a socket and bind it
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;
    if ((rv = getaddrinfo(NULL, PORT, &hints, &ai)) != 0) {
        fprintf(stderr, "pollserver: %s\n", gai_strerror(rv));
        exit(1);
    }

    for(p = ai; p != NULL; p = p->ai_next) {
        listener = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol);
        if (listener < 0) {
            continue;
        }

        // Lose the pesky "address already in use" error message
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes,
                sizeof(int));

        if (bind(listener, p->ai_addr, p->ai_addrlen) < 0) {
            close(listener);
            continue;
        }

        break;
    }

    // If we got here, it means we didn't get bound
    if (p == NULL) {
        return -1;
    }

    freeaddrinfo(ai); // All done with this

    // Listen
    if (listen(listener, 10) == -1) {
        return -1;
    }

    return listener;
}

/*
 * Add a new file descriptor to the set.
 */
void add_to_pfds(struct pollfd **pfds, int newfd, int *fd_count,
        int *fd_size)
{
    // If we don't have room, add more space in the pfds array
    if (*fd_count == *fd_size) {
        *fd_size *= 2; // Double it
        *pfds = realloc(*pfds, sizeof(**pfds) * (*fd_size));
    }

    (*pfds)[*fd_count].fd = newfd;
    (*pfds)[*fd_count].events = POLLIN; // Check ready-to-read
    (*pfds)[*fd_count].revents = 0;

    (*fd_count)++;
}

/*
 * Remove a file descriptor at a given index from the set.
 */
void del_from_pfds(struct pollfd pfds[], int i, int *fd_count)
{
    // Copy the one from the end over this one
    pfds[i] = pfds[*fd_count-1];

    (*fd_count)--;
}

/*
 * Handle incoming connections.
 */
void handle_new_connection(int listener, int *fd_count,
        int *fd_size, struct pollfd **pfds)
{
    struct sockaddr_storage remoteaddr; // Client address
    socklen_t addrlen;
    int newfd;  // Newly accept()ed socket descriptor
    char remoteIP[INET6_ADDRSTRLEN];

    addrlen = sizeof remoteaddr;
    newfd = accept(listener, (struct sockaddr *)&remoteaddr,
            &addrlen);

    if (newfd == -1) {
        perror("accept");
    } else {
        add_to_pfds(pfds, newfd, fd_count, fd_size);

        printf("pollserver: new connection from %s on socket %d\n",
                inet_ntop2(&remoteaddr, remoteIP, sizeof remoteIP),
                newfd);
    }
}

/*
 * Handle regular client data or client hangups.
 */
void handle_client_data(int listener, int *fd_count,
        struct pollfd *pfds, int *pfd_i)
{
    char buf[256];    // Buffer for client data

    int nbytes = recv(pfds[*pfd_i].fd, buf, sizeof buf, 0);

    int sender_fd = pfds[*pfd_i].fd;

    if (nbytes <= 0) { // Got error or connection closed by client
        if (nbytes == 0) {
            // Connection closed
            printf("pollserver: socket %d hung up\n", sender_fd);
        } else {
            perror("recv");
        }

        close(pfds[*pfd_i].fd); // Bye!

        del_from_pfds(pfds, *pfd_i, fd_count);

        // reexamine the slot we just deleted
        (*pfd_i)--;

    } else { // We got some good data from a client
        printf("pollserver: recv from fd %d: %.*s", sender_fd,
                nbytes, buf);
        // Send to everyone!
        for(int j = 0; j < *fd_count; j++) {
            int dest_fd = pfds[j].fd;

            // Except the listener and ourselves
            if (dest_fd != listener && dest_fd != sender_fd) {
                if (send(dest_fd, buf, nbytes, 0) == -1) {
                    perror("send");
                }
            }
        }
    }
}

/*
 * Process all existing connections.
 */
void process_connections(int listener, int *fd_count, int *fd_size,
        struct pollfd **pfds)
{
    for(int i = 0; i < *fd_count; i++) {

        // Check if someone's ready to read
        if ((*pfds)[i].revents & (POLLIN | POLLHUP)) {
            // We got one!!

            if ((*pfds)[i].fd == listener) {
                // If we're the listener, it's a new connection
                handle_new_connection(listener, fd_count, fd_size,
                        pfds);
            } else {
                // Otherwise we're just a regular client
                handle_client_data(listener, fd_count, *pfds, &i);
            }
        }
    }
}

/*
 * Main: create a listener and connection set, loop forever
 * processing connections.
 */
int main(void)
{
    int listener;     // Listening socket descriptor

    // Start off with room for 5 connections
    // (We'll realloc as necessary)
    int fd_size = 5;
    int fd_count = 0;
    struct pollfd *pfds = malloc(sizeof *pfds * fd_size);

    // Set up and get a listening socket
    listener = get_listener_socket();

    if (listener == -1) {
        fprintf(stderr, "error getting listening socket\n");
        exit(1);
    }

    // Add the listener to set;
    // Report ready to read on incoming connection
    pfds[0].fd = listener;
    pfds[0].events = POLLIN;

    fd_count = 1; // For the listener

    puts("pollserver: waiting for connections...");

    // Main loop
    for(;;) {
        int poll_count = poll(pfds, fd_count, -1);

        if (poll_count == -1) {
            perror("poll");
            exit(1);
        }

        // Run through connections looking for data to read
        process_connections(listener, &fd_count, &fd_size, &pfds);
    }

    free(pfds);
}
```

次の節では、似た古い関数 `select()` を見る。`select()` と `poll()` は似た機能とパフォーマンスを提供し、本当の違いは使い方だけだ。`select()` の方がやや移植性が高いかもしれないが、使い勝手は少しぎこちないかもしれない。システムでサポートされているなら、好きな方を選べばいい。

[i[poll()]>]


## `select()`——同期 I/O 多重化、オールドスクール {#select}

[i[`select()` function]<]

この関数はやや奇妙だが、とても便利だ。次の状況を想像してほしい：あなたはサーバーで、着信接続を待ちながら、すでにある接続からも読み続けたい。

問題ない、と言うだろう、`accept()` と `recv()` をいくつか。ちょっと待て、相棒！ `accept()` でブロックしているとき、同時に `recv()` でデータを読むにはどうする？ 「ノンブロッキングソケットを使え！」 だめだ！ CPU ホグにはなりたくない。じゃあどうする？

`select()` は複数のソケットを同時に監視する力を与えてくれる。どれが読み込み準備完了か、どれが書き込み準備完了か、本当に知りたければどれで例外が起きたかも教えてくれる。

> _注意：`select()` は非常に移植性が高いが、接続数が膨大なときはひどく遅い。そういう状況では、システムで使える最速の方法を選ぼうとする [fl[libevent|https://libevent.org/]] のようなイベントライブラリの方がパフォーマンスが良い。_

さらなる前置きなしに、`select()` の概要を示す：

```{.c}
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

int select(int numfds, fd_set *readfds, fd_set *writefds,
           fd_set *exceptfds, struct timeval *timeout); 
```

この関数はファイル記述子の「セット」を監視する。特に `readfds`、`writefds`、`exceptfds` だ。標準入力とソケット記述子 `sockfd` から読めるか見たいなら、ファイル記述子 `0` と `sockfd` をセット `readfds` に追加する。パラメータ `numfds` は最高のファイル記述子の値プラス 1 に設定すべきだ。この例では `sockfd+1` にすべきだ。標準入力（`0`）より確実に大きいからだ。

`select()` が戻ると、`readfds` は変更され、選択したうちどれが読み込み準備完了かを反映する。下のマクロ `FD_ISSET()` でテストできる。

先に進む前に、これらのセットの操作について話そう。各セットは型 `fd_set` だ。次のマクロがこの型を操作する：

| 関数                         | 説明                                 |
|------------------------------|--------------------------------------|
| [i[`FD_SET()` macro]]`FD_SET(int fd, fd_set *set);`   | `fd` を `set` に追加する。           |
| [i[`FD_CLR()` macro]]`FD_CLR(int fd, fd_set *set);`   | `fd` を `set` から削除する。         |
| [i[`FD_ISSET()` macro]]`FD_ISSET(int fd, fd_set *set);` | `fd` が `set` にあれば真を返す。 |
| [i[`FD_ZERO()` macro]]`FD_ZERO(fd_set *set);`          | `set` の全エントリをクリアする。     |

[i[`struct timeval` type]<]

最後に、この変わった `struct timeval` とは何だ？ 誰かがデータを送ってくるのを永遠に待ちたくないときがある。たとえ何も起きていなくても 96 秒ごとにターミナルに "Still Going..." と出したい、など。この時間構造体でタイムアウト期間を指定できる。時間を超えても `select()` が準備完了のファイル記述子を見つけられなければ、戻って処理を続けられる。

`struct timeval` には次のフィールドがある：

```{.c}
struct timeval {
    int tv_sec;     // seconds
    int tv_usec;    // microseconds
}; 
```

`tv_sec` を待つ秒数に、`tv_usec` を待つマイクロ秒数に設定する。そう、_マイクロ_秒であってミリ秒ではない。1 ミリ秒に 1000 マイクロ秒、1 秒に 1000 ミリ秒。つまり 1 秒に 1,000,000 マイクロ秒。なぜ "usec"？ "u" は「マイクロ」のギリシャ文字 μ（Mu）に似せたものだ。また、関数が戻ると `timeout` は _場合によって_ 残り時間を示すよう更新される。動いている Unix の種類による。

やった！ マイクロ秒解像度のタイマーだ！ まあ、当てにしない方がいい。`struct timeval` をどんなに小さくしても、標準の Unix タイムスライスの一部は待つことになるだろう。

他に興味深いこと：`struct timeval` のフィールドを `0` にすると、`select()` は即座にタイムアウトし、実質セット内の全ファイル記述子をポーリングする。パラメータ `timeout` を NULL にすると、決してタイムアウトせず、最初のファイル記述子が準備完了するまで待つ。最後に、特定のセットを待つ必要がなければ、`select()` 呼び出しで NULL にできる。

[flx[次のコード片|select.c]] は標準入力に何か現れるまで 2.5 秒待つ：

```{.c .numberLines}
/*
** select.c -- a select() demo
*/

#include <stdio.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#define STDIN 0  // file descriptor for standard input

int main(void)
{
    struct timeval tv;
    fd_set readfds;

    tv.tv_sec = 2;
    tv.tv_usec = 500000;

    FD_ZERO(&readfds);
    FD_SET(STDIN, &readfds);

    // don't care about writefds and exceptfds:
    select(STDIN+1, &readfds, NULL, NULL, &tv);

    if (FD_ISSET(STDIN, &readfds))
        printf("A key was pressed!\n");
    else
        printf("Timed out.\n");

    return 0;
} 
```

行バッファのターミナルなら、押したキーは RETURN でないとタイムアウトするだろう。

さて、データグラムソケットでデータを待つのにこれは素晴らしい方法だと思う人もいる——その通り _かもしれない_。一部の Unix ではこの使い方ができ、一部ではできない。試すならローカルの man ページで確認すべきだ。

一部の Unix はタイムアウトまでの残り時間を反映するよう `struct timeval` の時間を更新する。他はしない。移植性を重視するならそれに頼らないこと。（経過時間を追跡するなら [i[`gettimeofday()` function]] `gettimeofday()` を使え。残念だが、そういうものだ。）

[i[`struct timeval` type]>]

読み込みセットのソケットが接続を閉じたらどうなる？ その場合、`select()` はそのソケット記述子を「読み込み準備完了」としてセットした状態で戻る。実際にそこから `recv()` すると、`recv()` は `0` を返す。クライアントが接続を閉じたことがわかる方法だ。

`select()` についてもう一つ：[i[`select()` function-->with `listen()`]]
[i[`listen()` function-->with `select()`]]
`listen()` しているソケットがあれば、そのソケットのファイル記述子を `readfds` セットに入れることで新しい接続があるか調べられる。

というわけで、万能の `select()` 関数のざっとした概要だ。

ただし、人気の要望に応えて、詳しい例を載せる。残念ながら、上の超シンプルな例とここでの例の差はかなり大きい。でも見て、そのあと続く説明を読んでほしい。

[flx[このプログラム|selectserver.c]] はシンプルなマルチユーザーチャットサーバーのように動く。1 つのウィンドウで起動し、他の複数のウィンドウから `telnet` する（"`telnet hostname 9034`"）。1 つの `telnet` セッションで打ったものが、他のすべてに現れるはずだ。

```{.c .numberLines}
/*
** selectserver.c -- a cheezy multiperson chat server
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#define PORT "9034"   // port we're listening on

/*
 * Convert socket to IP address string.
 * addr: struct sockaddr_in or struct sockaddr_in6
 */
const char *inet_ntop2(void *addr, char *buf, size_t size)
{
    struct sockaddr_storage *sas = addr;
    struct sockaddr_in *sa4;
    struct sockaddr_in6 *sa6;
    void *src;

    switch (sas->ss_family) {
        case AF_INET:
            sa4 = addr;
            src = &(sa4->sin_addr);
            break;
        case AF_INET6:
            sa6 = addr;
            src = &(sa6->sin6_addr);
            break;
        default:
            return NULL;
    }

    return inet_ntop(sas->ss_family, src, buf, size);
}

/*
 * Return a listening socket
 */
int get_listener_socket(void)
{
    struct addrinfo hints, *ai, *p;
    int yes=1;    // for setsockopt() SO_REUSEADDR, below
    int rv;
    int listener;

    // get us a socket and bind it
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;
    if ((rv = getaddrinfo(NULL, PORT, &hints, &ai)) != 0) {
        fprintf(stderr, "selectserver: %s\n", gai_strerror(rv));
        exit(1);
    }

    for(p = ai; p != NULL; p = p->ai_next) {
        listener = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol);
        if (listener < 0) {
            continue;
        }

        // lose the pesky "address already in use" error message
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes,
                sizeof(int));

        if (bind(listener, p->ai_addr, p->ai_addrlen) < 0) {
            close(listener);
            continue;
        }

        break;
    }

    // if we got here, it means we didn't get bound
    if (p == NULL) {
        fprintf(stderr, "selectserver: failed to bind\n");
        exit(2);
    }

    freeaddrinfo(ai); // all done with this

    // listen
    if (listen(listener, 10) == -1) {
        perror("listen");
        exit(3);
    }

    return listener;
}

/*
 * Add new incoming connections to the proper sets
 */
void handle_new_connection(int listener, fd_set *master, int *fdmax)
{
    socklen_t addrlen;
    int newfd;        // newly accept()ed socket descriptor
    struct sockaddr_storage remoteaddr; // client address
    char remoteIP[INET6_ADDRSTRLEN];

    addrlen = sizeof remoteaddr;
    newfd = accept(listener,
        (struct sockaddr *)&remoteaddr,
        &addrlen);

    if (newfd == -1) {
        perror("accept");
    } else {
        FD_SET(newfd, master); // add to master set
        if (newfd > *fdmax) {  // keep track of the max
            *fdmax = newfd;
        }
        printf("selectserver: new connection from %s on "
            "socket %d\n",
            inet_ntop2(&remoteaddr, remoteIP, sizeof remoteIP),
            newfd);
    }
}

/*
 * Broadcast a message to all clients
 */
void broadcast(char *buf, int nbytes, int listener, int s,
               fd_set *master, int fdmax)
{
    for(int j = 0; j <= fdmax; j++) {
        // send to everyone!
        if (FD_ISSET(j, master)) {
            // except the listener and ourselves
            if (j != listener && j != s) {
                if (send(j, buf, nbytes, 0) == -1) {
                    perror("send");
                }
            }
        }
    }
}

/*
 * Handle client data and hangups
 */
void handle_client_data(int s, int listener, fd_set *master,
                        int fdmax)
{
    char buf[256];    // buffer for client data
    int nbytes;

    // handle data from a client
    if ((nbytes = recv(s, buf, sizeof buf, 0)) <= 0) {
        // got error or connection closed by client
        if (nbytes == 0) {
            // connection closed
            printf("selectserver: socket %d hung up\n", s);
        } else {
            perror("recv");
        }
        close(s); // bye!
        FD_CLR(s, master); // remove from master set
    } else {
        // we got some data from a client
        broadcast(buf, nbytes, listener, s, master, fdmax);
    }
}

/*
 * Main
 */
int main(void)
{
    fd_set master;    // master file descriptor list
    fd_set read_fds;  // temp file descriptor list for select()
    int fdmax;        // maximum file descriptor number

    int listener;     // listening socket descriptor

    FD_ZERO(&master);    // clear the master and temp sets
    FD_ZERO(&read_fds);

    listener = get_listener_socket();

    // add the listener to the master set
    FD_SET(listener, &master);

    // keep track of the biggest file descriptor
    fdmax = listener; // so far, it's this one

    // main loop
    for(;;) {
        read_fds = master; // copy it
        if (select(fdmax+1, &read_fds, NULL, NULL, NULL) == -1) {
            perror("select");
            exit(4);
        }

        // run through the existing connections looking for data
        // to read
        for(int i = 0; i <= fdmax; i++) {
            if (FD_ISSET(i, &read_fds)) { // we got one!!
                if (i == listener)
                    handle_new_connection(i, &master, &fdmax);
                else
                    handle_client_data(i, listener, &master, fdmax);
            }
        }
    }

    return 0;
}
```

コードにファイル記述子セットが 2 つあることに注意：`master` と `read_fds` だ。最初の `master` は、現在接続されているすべてのソケット記述子と、新しい接続を待っているリスニング用ソケット記述子を保持する。

`master` セットがある理由は、`select()` が実際に渡したセットを _変更_ して、どのソケットが読み込み準備完了かを反映するからだ。`select()` の呼び出しから次の呼び出しまで接続を追跡する必要があるので、安全な場所に保存しておかなければならない。直前に `master` を `read_fds` にコピーしてから `select()` を呼ぶ。

でも新しい接続のたびに `master` セットに追加しなければならないのか？ そうだ！ 接続が閉じるたびに `master` から削除する？ はい、その通りだ。

`listener` ソケットが読み込み準備完了になったときをチェックする。そうなれば新しい接続が保留中で、`accept()` して `master` セットに追加する。同様に、クライアント接続が読み込み準備完了で `recv()` が `0` を返せば、クライアントが接続を閉じたことがわかり、`master` セットから削除しなければならない。

クライアントの `recv()` がゼロ以外を返せば、データを受信したことがわかる。それを取得し、`master` リストを走査して、接続中の他のクライアントすべてにそのデータを送る。

というわけで、万能の `select()` 関数の、あまりシンプルではない概要だ。

Linux ファンの皆さんへのクイックメモ：まれな状況で、Linux の `select()` は「読み込み準備完了」と返したのに実際には読めないことがある！ つまり `select()` が読めると言ったあと `read()` でブロックする！ この小僧め——！ とにかく回避策は、受信ソケットに [i[`O_NONBLOCK` macro]] `O_NONBLOCK` フラグを設定して `EWOULDBLOCK` でエラーにし（起きたら無視してよい）、ソケットをノンブロッキングに設定する方法だ。詳細は [`fcntl()` リファレンスページ](#fcntlman) を参照。

加えて、ボーナスの余談：`select()` とほぼ同じように動くが、ファイル記述子セットの管理方法が違う [i[`poll()` function]] `poll()` という別の関数もある。[チェックしてみて！](#pollman)

[i[`select()` function]>]


## 部分的な `send()` の処理 {#sendall}

上の [`send()` の節](#sendrecv) で、`send()` は要求したバイト数をすべて送らないかもしれないと言ったのを覚えているだろうか？ 512 バイト送りたいのに 412 を返す。残りの 100 バイトはどうなった？

まだ小さなバッファに残っていて、送られるのを待っている。制御不能の事情で、カーネルはデータを一度に全部送らないことにした。あとは自分でデータを届けるしかない。

[i[`sendall()` function]<]
こんな関数を書いてもいい：

```{.c .numberLines}
#include <sys/types.h>
#include <sys/socket.h>

int sendall(int s, char *buf, int *len)
{
    int total = 0;        // how many bytes we've sent
    int bytesleft = *len; // how many we have left to send
    int n;

    while(total < *len) {
        n = send(s, buf+total, bytesleft, 0);
        if (n == -1) { break; }
        total += n;
        bytesleft -= n;
    }

    *len = total; // return number actually sent here

    return n==-1?-1:0; // return -1 on failure, 0 on success
} 
```

この例では、`s` はデータを送るソケット、`buf` はデータを含むバッファ、`len` はバッファ内のバイト数を含む `int` へのポインタだ。

関数はエラーで `-1` を返す（`errno` は `send()` 呼び出しのまま設定されている）。また、実際に送られたバイト数は `len` に返される。エラーがなければ要求したバイト数と同じになるはずだ。`sendall()` は懸命にデータを送り出すが、エラーがあればすぐに知らせてくれる。

完全性のため、関数呼び出しのサンプル：

```{.c .numberLines}
char buf[10] = "Beej!";
int len;

len = strlen(buf);
if (sendall(s, buf, &len) == -1) {
    perror("sendall");
    printf("We only sent %d bytes because of the error!\n", len);
} 
```

[i[`sendall()` function]>]

受信側でパケットの一部だけ届いたらどうなる？ パケット長が可変なら、受信側は1 つのパケットがどこで終わり次がどこから始まるかどう知る？ そう、現実のシナリオは [i[Donkeys]] ロバの尻尾を引っ張るような面倒だ。[i[Data encapsulation]] _カプセル化_ が必要だろう（最初の方の [データカプセル化の節](#lowlevel) を覚えているか？） 詳細は続きを読んで！


## シリアライゼーション——データのパック方法 {#serialization}

[i[Serialization]<]

テキストデータをネットワーク越しに送るのは簡単だとわかってきたが、`int` や `float` のような「バイナリ」データを送りたいときはどうする？ 選択肢がいくつかある。

1. `sprintf()` のような関数で数をテキストに変換してから送る。受信側は `strtol()` のような関数でテキストを数に戻す。

2. データをそのまま送る。データへのポインタを `send()` に渡す。

3. 数を移植可能なバイナリ形式にエンコードする。受信側がデコードする。

予告編！ 今夜限定！

[_幕が上がる_]

Beej が言う、「上の方法 3 が好きだ！」

[_終わり_]

（本題に入る前に、これをやるライブラリが世の中にあるし、自分で作って移植性とエラーフリーさを保つのはかなり大変だと言っておく。自分で実装する前に探して調べること。ここではこういうものがどう動くか興味がある人向けに情報を載せている。）

実際、上の方法すべてに長所と短所があるが、言ったように一般には 3 番目が好きだ。まず他の 2 つの長所と短所について話そう。

最初の方法、送る前に数をテキストにエンコードするには、ワイヤ上のデータを簡単に表示・読める利点がある。帯域をあまり気にしない状況では、人間が読めるプロトコルは優秀だ。たとえば [i[IRC]] [fl[Internet Relay Chat (IRC)|https://en.wikipedia.org/wiki/Internet_Relay_Chat]] など。ただし変換が遅く、結果はほぼ常に元の数よりスペースを食う短所がある。

方法 2：生データを渡す。これはかなり簡単（だが危険！）：送るデータへのポインタを取り、それで `send` を呼ぶだけだ。

```{.c}
double d = 3490.15926535;

send(s, &d, sizeof d, 0);  /* DANGER--non-portable! */
```

受信側はこう受け取る：

```{.c}
double d;

recv(s, &d, sizeof d, 0);  /* DANGER--non-portable! */
```

速くてシンプル——何が嫌？ すべてのアーキテクチャが `double`（`int` も同様）を同じビット表現、同じバイト順で表すわけではない！ コードは明らかに非移植的だ。（移植性が要らないなら、これは速くて素敵だ。）

整数型をパックするときは、[i[`htons()` function]] `htons()` 系の関数が数を [i[Byte ordering]] ネットワークバイトオーダーに変換して移植性を保つのに役立ち、それが正しいやり方だとすでに見てきた。残念ながら `float` 型用の同様の関数はない。希望はないのか？

恐れるな！（一瞬怖かったか？ いや？ ちょっとも？）できることがある：データを受信側がリモートでアンパックできる既知のバイナリ形式にパック（または「marshal」「serialize」など、他に千百万の名前のひとつ）する。

「既知のバイナリ形式」とは？ `htons()` の例をすでに見ただろう？ ホスト形式の数をネットワークバイトオーダーに変（または「エンコード」と考えてもよい）する。数を元に戻す（アンエンコード）には、受信側が `ntohs()` を呼ぶ。

でも整数以外の型にはそんな関数はないと言い終わったばかりでは？ そうだ。そして C でこれを標準的にやる方法はないので、ちょっと困った（Python ファン向けの洒落だ）。

やることは、データを既知の形式にパックしてワイヤ越しに送り、デコード用に渡すことだ。たとえば `float` をパックするなら、[flx[手っ取り早いが改善の余地たっぷりなもの|pack.c]] がある：

```{.c .numberLines}
#include <stdint.h>

uint32_t htonf(float f)
{
    uint32_t p;
    uint32_t sign;

    if (f < 0) { sign = 1; f = -f; }
    else { sign = 0; }
        
    // whole part and sign
    p = ((((uint32_t)f)&0x7fff)<<16) | (sign<<31);

    // fraction
    p |= (uint32_t)(((f - (int)f) * 65536.0f))&0xffff;

    return p;
}

float ntohf(uint32_t p)
{
    float f = ((p>>16)&0x7fff); // whole part
    f += (p&0xffff) / 65536.0f; // fraction

    if (((p>>31)&0x1) == 0x1) { f = -f; } // sign bit set

    return f;
}
```

上のコードは `float` を 32 ビット数に格納する素朴な実装だ。最上位ビット（31）は符号（「1」は負）、次の 7 ビット（30–16）は `float` の整数部、残り（15–0）は小数部を格納する。

使い方はかなり直感的：

```{.c .numberLines}
#include <stdio.h>

int main(void)
{
    float f = 3.1415926, f2;
    uint32_t netf;

    netf = htonf(f);  // convert to "network" form
    f2 = ntohf(netf); // convert back to test

    printf("Original: %f\n", f);        // 3.141593
    printf(" Network: 0x%08X\n", netf); // 0x0003243F
    printf("Unpacked: %f\n", f2);       // 3.141586

    return 0;
}
```

プラス面は小さくシンプルで速い。マイナス面はスペース効率が悪く、範囲が厳しく制限される——32767 より大きい数を入れようとするとあまり喜ばない！ 上の例でも最後の小数桁が正しく保持されていないのがわかる。

代わりに何ができる？ 浮動小数点数を格納する _標準_ は [i[IEEE-754]] [fl[IEEE-754|https://en.wikipedia.org/wiki/IEEE_754]] として知られている。ほとんどのコンピュータは内部の浮動小数点演算にこの形式を使うので、厳密に言えば変換は不要な場合もある。だがソースコードを移植可能にしたいなら、それは必ずしも仮定できない。

本当に？ おそらくシステムは IEEE-754 で、整数が 2 の補数であるのと同様だ。それが手元にあるとわかっていれば、データをワイヤ越しに渡せる（ただし `htonl()` や適切な関数でエンディアンを直す必要がある——`float` にもエンディアンがある）。これがビッグエンディアンで変換不要なシステムでの `htons()` などのやり方だ。

IEEE-754 でないシステムにいる場合に備えて、[flx[`float` と `double` を IEEE-754 形式にエンコードするコード|ieee754.c]] がある。（ほぼ——NaN や Infinity はエンコードしないが、修正すればできる。）

```{.c .numberLines}
#define pack754_32(f) (pack754((f), 32, 8))
#define pack754_64(f) (pack754((f), 64, 11))
#define unpack754_32(i) (unpack754((i), 32, 8))
#define unpack754_64(i) (unpack754((i), 64, 11))

uint64_t pack754(long double f, unsigned bits, unsigned expbits)
{
    long double fnorm;
    int shift;
    long long sign, exp, significand;

    // -1 for sign bit
    unsigned significandbits = bits - expbits - 1;

    if (f == 0.0) return 0; // get this special case out of the way

    // check sign and begin normalization
    if (f < 0) { sign = 1; fnorm = -f; }
    else { sign = 0; fnorm = f; }

    // get the normalized form of f and track the exponent
    shift = 0;
    while(fnorm >= 2.0) { fnorm /= 2.0; shift++; }
    while(fnorm < 1.0) { fnorm *= 2.0; shift--; }
    fnorm = fnorm - 1.0;

    // calculate the binary form (non-float) of the significand data
    significand = fnorm * ((1LL<<significandbits) + 0.5f);

    // get the biased exponent
    exp = shift + ((1<<(expbits-1)) - 1); // shift + bias

    // return the final answer
    return (sign<<(bits-1)) | (exp<<(bits-expbits-1)) | significand;
}

long double unpack754(uint64_t i, unsigned bits, unsigned expbits)
{
    long double result;
    long long shift;
    unsigned bias;

    // -1 for sign bit
    unsigned significandbits = bits - expbits - 1;

    if (i == 0) return 0.0;

    // pull the significand
    result = (i&((1LL<<significandbits)-1)); // mask
    result /= (1LL<<significandbits); // convert back to float
    result += 1.0f; // add the one back on

    // deal with the exponent
    bias = (1<<(expbits-1)) - 1;
    shift = ((i>>significandbits)&((1LL<<expbits)-1)) - bias;
    while(shift > 0) { result *= 2.0; shift--; }
    while(shift < 0) { result /= 2.0; shift++; }

    // sign it
    result *= (i>>(bits-1))&1? -1.0: 1.0;

    return result;
}
```

上に 32 ビット（おそらく `float`）と 64 ビット（おそらく `double`）用の便利なマクロを置いたが、`pack754()` を直接呼んで `bits` 分のデータ（うち `expbits` は正規化数の指数用）をエンコードさせることもできる。

使用例：

```{.c .numberLines}

#include <stdio.h>
#include <stdint.h> // defines uintN_t types
#include <inttypes.h> // defines PRIx macros

int main(void)
{
    float f = 3.1415926, f2;
    double d = 3.14159265358979323, d2;
    uint32_t fi;
    uint64_t di;

    fi = pack754_32(f);
    f2 = unpack754_32(fi);

    di = pack754_64(d);
    d2 = unpack754_64(di);

    printf("float before : %.7f\n", f);
    printf("float encoded: 0x%08" PRIx32 "\n", fi);
    printf("float after  : %.7f\n\n", f2);

    printf("double before : %.20lf\n", d);
    printf("double encoded: 0x%016" PRIx64 "\n", di);
    printf("double after  : %.20lf\n", d2);

    return 0;
}
```


上のコードは次の出力を出す：

```
float before : 3.1415925
float encoded: 0x40490FDA
float after  : 3.1415925

double before : 3.14159265358979311600
double encoded: 0x400921FB54442D18
double after  : 3.14159265358979311600
```

もう一つの疑問：`struct` はどうパックする？ 残念ながらコンパイラは `struct` 内に自由にパディングを入れられるので、全体を一塊で移植可能にワイヤ越しに送れない。（「これはできない」「あれはできない」と聞き飽きた？ すまない！ 友人の言葉を借りると「何か問題が起きるたびに、いつも Microsoft のせいにする」。今回は Microsoft のせいではないかもしれないが、友人の言葉は完全に正しい。）

本題に戻る：`struct` をワイヤ越しに送る最善の方法は、各フィールドを独立にパックし、反対側で到着したら `struct` にアンパックすることだ。

手間がかかる、と思うだろう。そうだ。できることは、パックを手伝うヘルパー関数を書くことだ。楽しいぞ！ 本当に！

Kernighan と Pike の [flr[_The Practice of Programming_|tpop]] では、`printf()` 風の `pack()` と `unpack()` を実装している。まさにこれをする。リンクしたいが、本のソースの残りと一緒にはオンラインにないらしい。

（_The Practice of Programming_ は素晴らしい一冊だ。おすすめするたびに Zeus が子猫を一匹救う。）

ここで [fl[Protocol Buffers の C 実装|https://github.com/protobuf-c/protobuf-c]] へのポインタを落とす。使ったことはないが、まったく信頼できそうだ。Python と Perl プログラマは、同じことをする言語の `pack()` と `unpack()` をチェックしたいだろう。Java には似た使い方の大きな Serializable インターフェースがある。

だが C で自分のパックユーティリティを書きたいなら、K&P の工夫は可変引数リストで `printf()` 風の関数を作りパケットを組み立てることだ。[flx[K&P を基に自分で作った版|pack2.c]] があり、そういうものがどう動くかのイメージには十分だろう。

（このコードは上の `pack754()` 関数を参照する。`packi*()` 関数はおなじみの `htons()` ファミリーと同様に動くが、別の整数ではなく `char` 配列にパックする。）

```{.c .numberLines}
#include <stdio.h>
#include <ctype.h>
#include <stdarg.h>
#include <string.h>

/*
** packi16() -- store a 16-bit int into a char buffer (like htons())
*/
void packi16(unsigned char *buf, unsigned int i)
{
    *buf++ = i>>8; *buf++ = i;
}

/*
** packi32() -- store a 32-bit int into a char buffer (like htonl())
*/
void packi32(unsigned char *buf, unsigned long int i)
{
    *buf++ = i>>24; *buf++ = i>>16;
    *buf++ = i>>8;  *buf++ = i;
}

/*
** packi64() -- store a 64-bit int into a char buffer (like htonl())
*/
void packi64(unsigned char *buf, unsigned long long int i)
{
    *buf++ = i>>56; *buf++ = i>>48;
    *buf++ = i>>40; *buf++ = i>>32;
    *buf++ = i>>24; *buf++ = i>>16;
    *buf++ = i>>8;  *buf++ = i;
}

/*
** unpacki16() -- unpack a 16-bit int from a char buffer (like
**                ntohs())
*/
int unpacki16(unsigned char *buf)
{
    unsigned int i2 = ((unsigned int)buf[0]<<8) | buf[1];
    int i;

    // change unsigned numbers to signed
    if (i2 <= 0x7fffu) { i = i2; }
    else { i = -1 - (unsigned int)(0xffffu - i2); }

    return i;
}

/*
** unpacku16() -- unpack a 16-bit unsigned from a char buffer (like
**                ntohs())
*/
unsigned int unpacku16(unsigned char *buf)
{
    return ((unsigned int)buf[0]<<8) | buf[1];
}

/*
** unpacki32() -- unpack a 32-bit int from a char buffer (like
**                ntohl())
*/
long int unpacki32(unsigned char *buf)
{
    unsigned long int i2 = ((unsigned long int)buf[0]<<24) |
                           ((unsigned long int)buf[1]<<16) |
                           ((unsigned long int)buf[2]<<8)  |
                           buf[3];
    long int i;

    // change unsigned numbers to signed
    if (i2 <= 0x7fffffffu) { i = i2; }
    else { i = -1 - (long int)(0xffffffffu - i2); }

    return i;
}

/*
** unpacku32() -- unpack a 32-bit unsigned from a char buffer (like
**                ntohl())
*/
unsigned long int unpacku32(unsigned char *buf)
{
    return ((unsigned long int)buf[0]<<24) |
           ((unsigned long int)buf[1]<<16) |
           ((unsigned long int)buf[2]<<8)  |
           buf[3];
}

/*
** unpacki64() -- unpack a 64-bit int from a char buffer (like
**                ntohl())
*/
long long int unpacki64(unsigned char *buf)
{
    unsigned long long int i2 =
        ((unsigned long long int)buf[0]<<56) |
        ((unsigned long long int)buf[1]<<48) |
        ((unsigned long long int)buf[2]<<40) |
        ((unsigned long long int)buf[3]<<32) |
        ((unsigned long long int)buf[4]<<24) |
        ((unsigned long long int)buf[5]<<16) |
        ((unsigned long long int)buf[6]<<8)  |
        buf[7];
    long long int i;

    // change unsigned numbers to signed
    if (i2 <= 0x7fffffffffffffffu) { i = i2; }
    else { i = -1 -(long long int)(0xffffffffffffffffu - i2); }

    return i;
}

/*
** unpacku64() -- unpack a 64-bit unsigned from a char buffer (like
**                ntohl())
*/
unsigned long long int unpacku64(unsigned char *buf)
{
    return ((unsigned long long int)buf[0]<<56) |
           ((unsigned long long int)buf[1]<<48) |
           ((unsigned long long int)buf[2]<<40) |
           ((unsigned long long int)buf[3]<<32) |
           ((unsigned long long int)buf[4]<<24) |
           ((unsigned long long int)buf[5]<<16) |
           ((unsigned long long int)buf[6]<<8)  |
           buf[7];
}

/*
** pack() -- store data dictated by the format string in the buffer
**
**   bits |signed   unsigned   float   string
**   -----+----------------------------------
**      8 |   c        C
**     16 |   h        H         f
**     32 |   l        L         d
**     64 |   q        Q         g
**      - |                               s
**
**  (16-bit unsigned length is automatically prepended to strings)
*/

unsigned int pack(unsigned char *buf, char *format, ...)
{
    va_list ap;

    signed char c;              // 8-bit
    unsigned char C;

    int h;                      // 16-bit
    unsigned int H;

    long int l;                 // 32-bit
    unsigned long int L;

    long long int q;            // 64-bit
    unsigned long long int Q;

    float f;                    // floats
    double d;
    long double g;
    unsigned long long int fhold;

    char *s;                    // strings
    unsigned int len;

    unsigned int size = 0;

    va_start(ap, format);

    for(; *format != '\0'; format++) {
        switch(*format) {
        case 'c': // 8-bit
            size += 1;
            c = (signed char)va_arg(ap, int); // promoted
            *buf++ = c;
            break;

        case 'C': // 8-bit unsigned
            size += 1;
            C = (unsigned char)va_arg(ap, unsigned int); // promoted
            *buf++ = C;
            break;

        case 'h': // 16-bit
            size += 2;
            h = va_arg(ap, int);
            packi16(buf, h);
            buf += 2;
            break;

        case 'H': // 16-bit unsigned
            size += 2;
            H = va_arg(ap, unsigned int);
            packi16(buf, H);
            buf += 2;
            break;

        case 'l': // 32-bit
            size += 4;
            l = va_arg(ap, long int);
            packi32(buf, l);
            buf += 4;
            break;

        case 'L': // 32-bit unsigned
            size += 4;
            L = va_arg(ap, unsigned long int);
            packi32(buf, L);
            buf += 4;
            break;

        case 'q': // 64-bit
            size += 8;
            q = va_arg(ap, long long int);
            packi64(buf, q);
            buf += 8;
            break;

        case 'Q': // 64-bit unsigned
            size += 8;
            Q = va_arg(ap, unsigned long long int);
            packi64(buf, Q);
            buf += 8;
            break;

        case 'f': // float-16
            size += 2;
            f = (float)va_arg(ap, double); // promoted
            fhold = pack754_16(f); // convert to IEEE 754
            packi16(buf, fhold);
            buf += 2;
            break;

        case 'd': // float-32
            size += 4;
            d = va_arg(ap, double);
            fhold = pack754_32(d); // convert to IEEE 754
            packi32(buf, fhold);
            buf += 4;
            break;

        case 'g': // float-64
            size += 8;
            g = va_arg(ap, long double);
            fhold = pack754_64(g); // convert to IEEE 754
            packi64(buf, fhold);
            buf += 8;
            break;

        case 's': // string
            s = va_arg(ap, char*);
            len = strlen(s);
            size += len + 2;
            packi16(buf, len);
            buf += 2;
            memcpy(buf, s, len);
            buf += len;
            break;
        }
    }

    va_end(ap);

    return size;
}

/*
** unpack() -- unpack data dictated by the format string into the
**             buffer
**
**   bits |signed   unsigned   float   string
**   -----+----------------------------------
**      8 |   c        C
**     16 |   h        H         f
**     32 |   l        L         d
**     64 |   q        Q         g
**      - |                               s
**
**  (string is extracted based on its stored length, but 's' can be
**  prepended with a max length)
*/
void unpack(unsigned char *buf, char *format, ...)
{
    va_list ap;

    signed char *c;              // 8-bit
    unsigned char *C;

    int *h;                      // 16-bit
    unsigned int *H;

    long int *l;                 // 32-bit
    unsigned long int *L;

    long long int *q;            // 64-bit
    unsigned long long int *Q;

    float *f;                    // floats
    double *d;
    long double *g;
    unsigned long long int fhold;

    char *s;
    unsigned int len, maxstrlen=0, count;

    va_start(ap, format);

    for(; *format != '\0'; format++) {
        switch(*format) {
        case 'c': // 8-bit
            c = va_arg(ap, signed char*);
            if (*buf <= 0x7f) { *c = *buf;} // re-sign
            else { *c = -1 - (unsigned char)(0xffu - *buf); }
            buf++;
            break;

        case 'C': // 8-bit unsigned
            C = va_arg(ap, unsigned char*);
            *C = *buf++;
            break;

        case 'h': // 16-bit
            h = va_arg(ap, int*);
            *h = unpacki16(buf);
            buf += 2;
            break;

        case 'H': // 16-bit unsigned
            H = va_arg(ap, unsigned int*);
            *H = unpacku16(buf);
            buf += 2;
            break;

        case 'l': // 32-bit
            l = va_arg(ap, long int*);
            *l = unpacki32(buf);
            buf += 4;
            break;

        case 'L': // 32-bit unsigned
            L = va_arg(ap, unsigned long int*);
            *L = unpacku32(buf);
            buf += 4;
            break;

        case 'q': // 64-bit
            q = va_arg(ap, long long int*);
            *q = unpacki64(buf);
            buf += 8;
            break;

        case 'Q': // 64-bit unsigned
            Q = va_arg(ap, unsigned long long int*);
            *Q = unpacku64(buf);
            buf += 8;
            break;

        case 'f': // float
            f = va_arg(ap, float*);
            fhold = unpacku16(buf);
            *f = unpack754_16(fhold);
            buf += 2;
            break;

        case 'd': // float-32
            d = va_arg(ap, double*);
            fhold = unpacku32(buf);
            *d = unpack754_32(fhold);
            buf += 4;
            break;

        case 'g': // float-64
            g = va_arg(ap, long double*);
            fhold = unpacku64(buf);
            *g = unpack754_64(fhold);
            buf += 8;
            break;

        case 's': // string
            s = va_arg(ap, char*);
            len = unpacku16(buf);
            buf += 2;
            if (maxstrlen > 0 && len > maxstrlen)
                count = maxstrlen - 1;
            else
                count = len;
            memcpy(s, buf, count);
            s[count] = '\0';
            buf += len;
            break;

        default:
            if (isdigit(*format)) { // track max str len
                maxstrlen = maxstrlen * 10 + (*format-'0');
            }
        }

        if (!isdigit(*format)) maxstrlen = 0;
    }

    va_end(ap);
}
```

そして上のコードの [flx[デモプログラム|pack2.c]] があり、データを `buf` にパックして変数にアンパックする。`unpack()` を文字列引数（書式指定子 "`s`"）で呼ぶときは、バッファオーバーランを防ぐため前に最大長を付けるのが賢明だ。たとえば "`96s`"。ネットワーク越しに受け取ったデータをアンパックするときは用心——悪意のあるユーザーがシステムを攻撃しようと不正なパケットを送ってくるかもしれない！

```{.c .numberLines}
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

// If you have a C23 compiler
#if __STDC_VERSION__ >= 202311L
#include <stdfloat.h>
#else
// Otherwise let's define our own.
// Varies for different architectures! But you're probably:
typedef float float32_t;
typedef double float64_t;
#endif

int main(void)
{
    uint8_t buf[1024];
    int8_t magic;
    int16_t monkeycount;
    int32_t altitude;
    float32_t absurdityfactor;
    char *s = "Great unmitigated Zot!  You've found the Runestaff!";
    char s2[96];
    int16_t packetsize, ps2;

    packetsize = pack(buf, "chhlsf", (int8_t)'B', (int16_t)0,
            (int16_t)37, (int32_t)-5, s, (float32_t)-3490.6677);
    packi16(buf+1, packetsize); // store packet size for kicks

    printf("packet is %" PRId32 " bytes\n", packetsize);

    unpack(buf, "chhl96sf", &magic, &ps2, &monkeycount, &altitude,
            s2, &absurdityfactor);

    printf("'%c' %" PRId32" %" PRId16 " %" PRId32
            " \"%s\" %f\n", magic, ps2, monkeycount,
            altitude, s2, absurdityfactor);
}
```

自分でコードを書くにせよ他人のを使うにせよ、毎回手でビットをパックするより、バグを抑えるための一般的なデータパック用ルーチンを持つのがよい。

データをパックするとき、どんな形式がよい？ 素晴らしい質問だ。幸い、[i[XDR]] [flrfc[RFC 4506|4506]]、External Data Representation Standard が、浮動小数点型、整数型、配列、生データなど、さまざまな型のバイナリ形式をすでに定義している。自分でデータを組むならそれに従うことを勧める。ただし義務ではない。パケット警察がドアの外にいるわけではない。少なくとも、_いない_ と思う。

いずれにせよ、送る前に何らかの形でデータをエンコードするのが正しいやり方だ！

[i[Serialization]>]


## データカプセル化の続編 {#sonofdataencap}

データをカプセル化するとは、いったい何を意味する？ 最も単純な場合、識別情報やパケット長、またはその両方を含むヘッダを先頭に付けることだ。

ヘッダはどう見えるべき？ プロジェクトを完成させるのに必要だと感じるものを表すバイナリデータだ。

ふーん。曖昧だ。

たとえば、マルチユーザーチャットプログラムが `SOCK_STREAM` を使うとする。ユーザーが何か打つ（「発言」する）と、サーバーに送る必要がある情報は 2 つ：何が言われたか、誰が言ったか。

ここまではいいか？ 「問題は？」と聞くだろう。

問題はメッセージの長さが可変だということだ。「tom」という人が "Hi" と言い、「Benjamin」が "Hey guys what is up?" と言うかもしれない。

だから届くたびにクライアントへ全部 `send()` する。送信データストリームはこう見える：

```
t o m H i B e n j a m i n H e y g u y s w h a t i s u p ?
```

などなど。クライアントは 1 つのメッセージがどこで始まり次がどこで終わるかどう知る？ 望むなら、すべてのメッセージを同じ長さにして、上で実装した [i[`sendall()` function]] `sendall()` を呼べる。[上](#sendall) を参照。だがそれは帯域の無駄だ！"tom" が "Hi" と言うのに 1024 バイト `send()` したくはない。

だからデータを小さなヘッダとパケット構造で _カプセル化_ する。クライアントもサーバーも、このデータのパックとアンパック（「marshal」「unmarshal」とも言う）の仕方を知っている。見ないで——クライアントとサーバーがどう通信するかを記述する _プロトコル_ を定義し始めている！

この場合、ユーザー名は 8 文字の固定長で、必要なら `'\0'` でパディングすると仮定しよう。データは可変長で最大 128 文字とする。この状況で使えそうなパケット構造の例：

1. `len`（1 バイト、符号なし）——8 バイトのユーザー名とチャットデータを含むパケットの総長。

2. `name`（8 バイト）——ユーザー名。必要なら NUL パディング。

3. `chatdata`（_n_ バイト）——データ本体。最大 128 バイト。パケット長はこのデータの長さプラス 8（上の名前フィールドの長さ）として計算すべき。

なぜフィールドに 8 バイトと 128 バイトの制限を選んだ？ 空から引っ張った。十分長いだろうと仮定した。8 バイトは要件に厳しすぎるかもしれない。30 バイトの名前フィールドにしてもよい。選ぶのはあなた次第だ。

上のパケット定義を使うと、最初のパケットは次の情報で構成される（16 進と ASCII）：

```
   0A     74 6F 6D 00 00 00 00 00      48 69
(length)  T  o  m    (padding)         H  i
```

2 番目も同様：

```
   18     42 65 6E 6A 61 6D 69 6E      48 65 79 20 67 75 79 73 20 77 ...
(length)  B  e  n  j  a  m  i  n       H  e  y     g  u  y  s     w  ...
```

（長さはもちろんネットワークバイトオーダーで格納される。この場合 1 バイトなので問題ないが、一般にはパケット内のバイナリ整数はすべてネットワークバイトオーダーで格納したい。）

このデータを送るときは安全のため、上の [`sendall()`](#sendall) と同様のコマンドを使い、複数回の `send()` が必要でもデータがすべて送られたことを確認すべきだ。

同様に、受信するときは少し余分な作業が必要だ。部分的なパケットを受け取るかもしれないと仮定すべきだ（たとえば上の Benjamin から "`18 42 65 6E 6A`" だけ受け取り、この `recv()` 呼び出しではそれだけ、など）。パケットが完全に受信されるまで `recv()` を繰り返し呼ぶ必要がある。

でもどうやって？ パケットが完了するために受信すべき総バイト数はわかっている。パケットの先頭にその数が付いているからだ。またパケットの最大サイズは 1+8+128、つまり 137 バイトだ（パケットをそう定義したから）。

実際にはいくつかできることがある。すべてのパケットが長さで始まるとわかっているので、パケット長だけ得るために `recv()` を呼べる。それがわかったら、パケットの残り長さを正確に指定して再度呼ぶ（必要なら繰り返して全部得る）まで、完全なパケットが揃う。この方法の利点は 1 パケット分のバッファだけでよいこと。欠点はデータを全部得るのに少なくとも 2 回 `recv()` が必要なことだ。

別の選択肢は、受け取る量の上限をパケットの最大バイト数にして `recv()` を呼ぶことだ。得たものはバッファの末尾に足し、パケットが完了したか確認する。もちろん次のパケットの一部が混ざるかもしれないので、その分のスペースも必要だ。

できることは、2 パケット分入る配列を宣言することだ。これが作業用バッファで、届くパケットを再構成する。

`recv()` でデータを得るたびに作業バッファに追記し、パケットが完了したか確認する。つまり、バッファ内のバイト数がヘッダで指定された長さ以上（+1。ヘッダの長さは長さ自身の 1 バイトを含まないから）。バッファ内のバイト数が 1 未満なら明らかにパケットは未完了だ。ただし最初のバイトはゴミなので正しいパケット長に頼れず、この場合は特別扱いが必要だ。

パケットが完了したら好きに使えばよい。使ったら作業バッファから削除する。

ふう！ 頭の中でジャグリングしているか？ ここで二段構えの 2 発目：1 回の `recv()` で 1 パケットの終わりを越えて次のパケットの途中まで読んでいるかもしれない。つまり、作業バッファに 1 つの完全なパケットと、次のパケットの未完成部分がある！ まったく。（だから作業バッファを _2_ パケット分入る大きさにした——こうなったときのためだ！）

ヘッダから最初のパケットの長さがわかり、作業バッファ内のバイト数を追跡してきたので、作業バッファのうち 2 番目（未完成）パケットに属するバイト数を引き算できる。最初を処理したら作業バッファから消し、未完成の 2 番目をバッファ先頭へ移して次の `recv()` の準備をする。

（読者の一部は、未完成の 2 番目パケットを作業バッファ先頭へ移すのに時間がかかること、循環バッファを使えばこれを不要にできるプログラムもあると気づくだろう。残念ながら循環バッファの議論はこの記事の範囲外だ。まだ興味があればデータ構造の本を手に入れてそこから始めてほしい。）

簡単だとは言わなかった。いや、簡単だと言った。そして簡単だ。練習すれば自然にできる。[i[Excalibur]] エクスカリバーにかけて誓う！


## ブロードキャストパケット——Hello, World!

これまでこのガイドは、1 ホストから別の 1 ホストへデータを送ることについて話してきた。だが可能だと主張する——適切な権限があれば、_同時に_ 複数ホストへデータを送れる！

[i[UDP]] UDP（UDP のみ、TCP ではない）と標準 IPv4 では、[i[Broadcast]] _ブロードキャスト_ という仕組みで行う。IPv6 ではブロードキャストはサポートされず、しばしば優れた _マルチキャスト_ に頼る必要があるが、残念ながら今回は論じない。だが夢見がちな未来はここまで——32 ビットの現在にいる。

だが待て！ いきなりブロードキャストし始けてはいけない。ネットワークへブロードキャストパケットを送る前に、[i[`setsockopt()` function]] ソケットオプション [i[`SO_BROADCAST` macro]] `SO_BROADCAST` を設定しなければならない。ミサイル発射スイッチにかぶせる小さなプラスチックカバーのようなものだ！ 手にする力はそれほどのものだ！

だが真面目な話、ブロードキャストパケットには危険がある。ブロードキャストパケットを受け取るすべてのシステムは、データが向かうポートがわかるまでデータカプセル化の玉ねぎの皮をすべて剥がさなければならない。そしてデータを渡すか捨てる。いずれにせよ、受信する各マシンにとって大仕事だ。ローカルネットワーク上のすべてが対象なので、不要な仕事をするマシンが大量にあるかもしれない。ゲーム Doom が初めて出たとき、ネットワークコードについてこういう不満があった。

さて、猫の皮の剥ぎ方は一つとは限らない[^6178]……ちょっと待て。本当に猫の皮の剥ぎ方は一つより多いのか？ どんな表現だ？ そして同様に、ブロードキャストパケットを送る方法も一つではない。本題へ：ブロードキャストメッセージの宛先アドレスはどう指定する？ よくある方法は 2 つ：

[^6178]: 記録として、猫は大好きだ。最高の相棒だ。長年たくさんの愛猫と過ごしてきた。由来は時の流れに失われたこの血みどろの比喩表現に異論を唱える人もいるが、このガイドのこの部分にはその使用が最適だと思う。

1. 特定サブネットのブロードキャストアドレスへ送る。サブネットのネットワーク番号に、ホスト部をすべて 1 にしたものだ。たとえば自宅ではネットワークが `192.168.1.0`、ネットマスクが `255.255.255.0` なので、アドレスの最後のバイトがホスト番号（ネットマスクによると最初の 3 バイトがネットワーク番号）。だからブロードキャストアドレスは `192.168.1.255` だ。Unix では `ifconfig` コマンドが実際にこれらすべてを教えてくれる。（興味があれば、ブロードキャストアドレスのビット論理は `network_number` OR (NOT `netmask`) だ。）この種のブロードキャストパケットはローカルだけでなくリモートネットワークにも送れるが、宛先のルーターがパケットを捨てるリスクがある。（捨てなければ、どこかのスマーフが LAN をブロードキャストトラフィックで溢れさせ始めるかもしれない。）

2. 「グローバル」ブロードキャストアドレスへ送る。これは [i[`255.255.255.255`]] `255.255.255.255`、別名 [i[`INADDR_BROADCAST` macro]] `INADDR_BROADCAST` だ。多くのマシンはこれをネットワーク番号と自動的にビットごと AND してネットワークブロードキャストアドレスに変換するが、しないものもある。さまざまだ。ルーターは皮肉なことに、この種のブロードキャストパケットをローカルネットワークの外へ転送しない。

では最初に `SO_BROADCAST` ソケットオプションを設定せずにブロードキャストアドレスへデータを送ろうとするとどうなる？ 古い [`talker` と `listener`](#datagram) を起動して確かめてみよう。

```
$ talker 192.168.1.2 foo
sent 3 bytes to 192.168.1.2
$ talker 192.168.1.255 foo
sendto: Permission denied
$ talker 255.255.255.255 foo
sendto: Permission denied
```

そう、まったく喜ばない……`SO_BROADCAST` ソケットオプションを設定していないからだ。設定すれば、好きなところへ `sendto()` できる！

実際、UDP アプリがブロードキャストできるかできないかの _唯一の違い_ はそれだけだ。だから古い `talker` アプリを取り、`SO_BROADCAST` ソケットオプションを設定する部分を 1 つ足そう。このプログラムを [flx[`broadcaster.c`|broadcaster.c]] と呼ぶ：

```{.c .numberLines}
/*
** broadcaster.c -- a datagram "client" like talker.c, except
**                  this one can broadcast
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

#define SERVERPORT 4950    // the port users will be connecting to

int main(int argc, char *argv[])
{
    int sockfd;
    struct sockaddr_in their_addr; // connector's address info
    struct hostent *he;
    int numbytes;
    int broadcast = 1;
    //char broadcast = '1'; // if that doesn't work, try this

    if (argc != 3) {
        fprintf(stderr,"usage: broadcaster hostname message\n");
        exit(1);
    }

    if ((he=gethostbyname(argv[1])) == NULL) {  // get the host info
        perror("gethostbyname");
        exit(1);
    }

    if ((sockfd = socket(PF_INET, SOCK_DGRAM, 0)) == -1) {
        perror("socket");
        exit(1);
    }

    // this call is what allows broadcast packets to be sent:
    if (setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &broadcast,
        sizeof broadcast) == -1) {
        perror("setsockopt (SO_BROADCAST)");
        exit(1);
    }

    their_addr.sin_family = AF_INET;     // host byte order
    their_addr.sin_port = htons(SERVERPORT); // network byte order
    their_addr.sin_addr = *((struct in_addr *)he->h_addr);
    memset(their_addr.sin_zero, '\0', sizeof their_addr.sin_zero);

    numbytes = sendto(sockfd, argv[2], strlen(argv[2]), 0,
             (struct sockaddr *)&their_addr, sizeof their_addr);

    if (numbytes == -1) {
        perror("sendto");
        exit(1);
    }

    printf("sent %d bytes to %s\n", numbytes,
        inet_ntoa(their_addr.sin_addr));

    close(sockfd);

    return 0;
}
```

これと「普通の」UDP クライアント／サーバー状況の違いは？ 何もない！（この場合クライアントがブロードキャストパケットを送れること以外。）なので、1 つのウィンドウで古い UDP [`listener`](#datagram) プログラムを動かし、別のウィンドウで `broadcaster` を動かせばいい。上で失敗した送信がすべてできるはずだ。

```
$ broadcaster 192.168.1.2 foo
sent 3 bytes to 192.168.1.2
$ broadcaster 192.168.1.255 foo
sent 3 bytes to 192.168.1.255
$ broadcaster 255.255.255.255 foo
sent 3 bytes to 255.255.255.255
```

`listener` がパケットを受け取ったと応答するはずだ。（`listener` が応答しない場合、IPv6 アドレスにバインドしている可能性がある。`listener.c` の `AF_INET6` を `AF_INET` に変えて IPv4 を強制してみてほしい。）

さて、これはちょっとワクワクする。だが同じネットワーク上の隣の別マシンでも `listener` を起動して 2 台で動かし、ブロードキャストアドレスで再び `broadcaster` を実行してみよう……おお！ `sendto()` は 1 回しか呼んでいないのに両方の `listener` がパケットを受け取る！ クールだ！

`listener` が直接送ったデータは受け取るがブロードキャストアドレスのデータは受け取らない場合、ローカルマシンの [i[Firewall]] ファイアウォールがパケットをブロックしている可能性がある。（そう、[i[Pat]] Pat と [i[Bapper]] Bapper、サンプルコードが動かなかった理由がこれだと私より先に気づいてくれてありがとう。ガイドで名前を出すと言ったから、ここにいる。だから _にゃー_。）

繰り返すが、ブロードキャストパケットには注意すること。LAN 上のすべてのマシンは `recvfrom()` するかどうかに関わらずパケットに対処を強いられるので、コンピューティングネットワーク全体にかなりの負荷になりうる。控えめに、適切な場面でのみ使うことだ。
