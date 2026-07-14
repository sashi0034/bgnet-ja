# よくある質問

**ヘッダファイルはどこで手に入る？**

[i[Header files]] システムにまだ入っていなければ、おそらく必要ない。使っているプラットフォームのマニュアルを確認してほしい。[i[Windows]] Windows 向けにビルドしているなら、`#include <winsock.h>` だけで足りる。

**`bind()` が [i[Address already in use]]「Address already in use」を報告したらどうする？**

リスニングソケットに [i[`setsockopt()` function]] `setsockopt()` と [i[`SO_REUSEADDR` macro]] `SO_REUSEADDR` オプションを使う必要がある。[i[`bind()` function]] [`bind()` の節](#bind) と [i[`select()` function]] [`select()` の節](#select) に例がある。

**システム上のオープンソケット一覧はどうやって取得する？**

[i[`netstat` command]] `netstat` を使う。詳細は `man` ページを見てほしいが、次のように打つだけでも十分な出力が得られる：

```
$ netstat
```

コツは、どのソケットがどのプログラムに紐づいているかを見分けることだ。`:-)`

**ルーティングテーブルはどうやって見る？**

[i[`route` command]] `route` コマンド（多くの Linux では `/sbin` にある）か、[i[`netstat` command]] `netstat -r`、あるいは [i[`ip route` command]] `ip route` を実行する。

**コンピュータが1台しかないのに、クライアントとサーバープログラムをどうやって動かす？ ネットワークプログラムを書くにはネットワークが必要じゃない？**

幸いなことに、ほぼすべてのマシンには [i[Loopback device]] ループバックネットワーク「デバイス」が実装されていて、カーネル内にあり、ネットワークカードのふりをする。（ルーティングテーブルで「`lo`」として列挙されているインターフェースだ。）

[i[Goat]] 「`goat`」という名前のマシンにログインしていると仮定しよう。1つのウィンドウでクライアント、もう1つでサーバーを動かす。あるいはサーバーをバックグラウンドで起動（「`server &`」）して、同じウィンドウでクライアントを動かす。ループバックデバイスの要点は、`client goat` でも [i[`localhost`]] `client localhost`（「`localhost`」は `/etc/hosts` に定義されていることが多い）でも、ネットワークなしでクライアントとサーバーが会話できることだ。

要するに、1台の非ネットワークマシンで動かすためにコードを変える必要はまったくない！ やったね！

**リモート側が接続を閉じたかどうかはどうやって分かる？**

`recv()` が `0` を返すので分かる。

**[i[`ping` command]]「ping」ユーティリティはどう実装する？ [i[ICMP]] ICMP とは？ [i[Raw sockets]] 生ソケットや `SOCK_RAW` についてもっと知るには？**

[i[`SOCK_RAW` macro]]

生ソケットに関する疑問はすべて [W. Richard Stevens の UNIX Network Programming シリーズ](#books) で答えが見つかる。Stevens の UNIX Network Programming ソースコードの `ping/` サブディレクトリも見てほしい。[fl[オンラインで入手可能|http://www.unpbook.com/src.html]]。

**`connect()` 呼び出しのタイムアウトを変更したり短くしたりするには？**

W. Richard Stevens がそのまま答えるであろう内容をここで繰り返す代わりに、[fl[UNIX Network Programming ソースコードの `lib/connect_nonb.c`|http://www.unpbook.com/src.html]] を参照してほしい。

要点は、`socket()` でソケットディスクリプタを作り、[非ブロッキングに設定](#blocking)し、`connect()` を呼ぶこと。うまくいけば `connect()` はすぐ `-1` を返し、`errno` は `EINPROGRESS` になる。次に好きなタイムアウトで [`select()`](#select) を呼び、ソケットディスクリプタを読み取りセットと書き込みセットの両方に渡す。タイムアウトしなければ `connect()` 呼び出しは完了したということ。この時点で `getsockopt()` と `SO_ERROR` オプションを使い、`connect()` 呼び出しの戻り値（エラーがなければ 0 のはず）を取得する。

最後に、ソケット上でデータ転送を始める前に、おそらくソケットを再びブロッキングに戻したいだろう。

これには接続中にプログラムが別のことをする余裕も生まれる、という副次効果もある。たとえばタイムアウトを 500 ms など低く設定し、タイムアウトのたびに画面上のインジケータを更新してから、また `select()` を呼ぶ。`select()` を呼んでタイムアウトした回数が、たとえば 20 回になったら、接続を諦める時だと分かる。

言ったとおり、Stevens のソースに完璧な例がある。

**Windows 向けにビルドするには？**

まず Windows を消して Linux か BSD を入れろ。`};-)` いや、本当は [はじめにの Windows 向けビルドの節](#windows) を見てほしい。

**Solaris/SunOS 向けにビルドするには？ コンパイルしようとするとリンカエラーが出続ける！**

リンカエラーは、Sun 系マシンではソケットライブラリが自動ではリンクされないから起きる。[はじめにの Solaris/SunOS 向けビルドの節](#solaris) に例がある。

**`select()` がシグナルで抜けてしまうのはなぜ？**

シグナルは、ブロック中のシステムコールが `-1` を返し `errno` が `EINTR` になる原因になりやすい。[i[`sigaction()` function]] `sigaction()` でシグナルハンドラを設定するとき、[i[`SA_RESTART` macro]] `SA_RESTART` フラグを設定できる。これは中断されたあとシステムコールを再開するはずだ。

当然、いつもうまくいくわけではない。

お気に入りの解決策は [i[`goto` statement]] `goto` 文を使うことだ。教授をイラッとさせる方法だから、ぜひやってみろ！

```{.c .numberLines}
select_restart:
if ((err = select(fdmax+1, &readfds, NULL, NULL, NULL)) == -1) {
    if (errno == EINTR) {
        // some signal just interrupted us, so restart
        goto select_restart;
    }
    // handle the real error here:
    perror("select");
} 
```

確かに、この場合に `goto` を使う _必要_ はない。制御のために別の構造を使ってもよい。でも `goto` 文のほうが実際にはすっきりしていると思う。

**`recv()` 呼び出しにタイムアウトを実装するには？**

[i[`recv()` function-->timeout]] [i[`select()` function]] [`select()`](#select) を使え！ 読み取りたいソケットディスクリプタにタイムアウトパラメータを指定できる。あるいは、次のように機能全体を1つの関数にまとめてもよい：

```{.c .numberLines}
#include <unistd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>

int recvtimeout(int s, char *buf, int len, int timeout)
{
    fd_set fds;
    int n;
    struct timeval tv;

    // set up the file descriptor set
    FD_ZERO(&fds);
    FD_SET(s, &fds);

    // set up the struct timeval for the timeout
    tv.tv_sec = timeout;
    tv.tv_usec = 0;

    // wait until timeout or data received
    n = select(s+1, &fds, NULL, NULL, &tv);
    if (n == 0) return -2; // timeout!
    if (n == -1) return -1; // error

    // data must be here, so do a normal recv()
    return recv(s, buf, len, 0);
}
.
.
.
// Sample call to recvtimeout():
n = recvtimeout(s, buf, sizeof buf, 10); // 10 second timeout

if (n == -1) {
    // error occurred
    perror("recvtimeout");
}
else if (n == -2) {
    // timeout occurred
} else {
    // got some data in buf
}
.
.
. 
```

[i[`recvtimeout()` function]] `recvtimeout()` はタイムアウト時に `-2` を返すことに注意。なぜ `0` じゃない？ 思い出してほしいが、`recv()` が `0` を返すのはリモート側が接続を閉じたという意味だ。つまりその戻り値はもう使われていて、`-1` は「エラー」なので、タイムアウト指標には `-2` を選んだ。

**ソケット経由で送る前にデータを [i[Encryption]] 暗号化したり圧縮したりするには？**

暗号化の簡単な方法の1つは [i[SSL]] SSL（Secure Sockets Layer）を使うことだが、それは本ガイドの範囲外だ。[i[OpenSSL]]（詳細は [fl[OpenSSL プロジェクト|https://www.openssl.org/]] を参照。）

ただし独自の [i[Compression]] 圧縮器や暗号化システムを差し込んだり実装したりするなら、両端の間をデータが一連のステップを通過するものと考えればよい。各ステップでデータは何らかの形で変わる。

1. サーバーがファイル（など）からデータを読む
2. サーバーがデータを暗号化／圧縮する（ここを自分で追加）
3. サーバーが暗号化データを `send()` する

逆方向はこう：

1. クライアントが暗号化データを `recv()` する
2. クライアントがデータを復号／展開する（ここを自分で追加）
3. クライアントがファイル（など）にデータを書く

圧縮と暗号化の両方をするなら、先に圧縮することを忘れないで。`:-)`

クライアントがサーバーの処理を正しく元に戻せば、途中にいくらステップを挟んでも最終的なデータは問題ない。

つまり、私のコードを使うには、データが読み込まれてから `send()` でネットワークに送られるまでの間に、暗号化を行うコードを差し込めばよい。

**「`PF_INET`」って何度も見るけど、`AF_INET` と関係ある？**

[i[`PF_INET` macro]] [i[`AF_INET` macro]]

ある、大いにある。詳細は [`socket()` の節](#socket) を参照。

**クライアントからシェルコマンドを受け取って実行するサーバーはどう書く？**

簡単にするため、クライアントは `connect()` して `send()` して `close()` する（つまり、クライアントが再接続しない限り後続のシステムコールはない）としよう。

クライアントの手順はこう：

1. サーバーに `connect()` する
2. `send("/sbin/ls > /tmp/client.out")` する
3. 接続を `close()` する

一方、サーバーはデータを処理して実行する：

1. クライアントからの接続を `accept()` する
2. コマンド文字列を `recv(str)` する
3. 接続を `close()` する
4. `system(str)` でコマンドを実行する

[i[Security]] _注意！_ サーバーがクライアントの言うことを実行するのは、リモートシェルアクセスを与えるようなもので、接続するとアカウント上で好き放題される。上の例だと、クライアントが「`rm -rf ~`」を送ったらどうなる？ アカウント内のすべてが消える、それだけだ！

賢くなって、クライアントには安全だと分かっている `foobar` ユーティリティなど、ほんの数個のユーティリティしか使わせないようにする：

```{.c}
if (!strncmp(str, "foobar", 6)) {
    sprintf(sysstr, "%s > /tmp/server.out", str);
    system(sysstr);
} 
```

でも残念ながらまだ安全ではない。クライアントが「`foobar; rm -rf ~`」と入力したらどうなる？ 最も安全なのは、コマンド引数の英数字以外（必要なら空白も含む）すべての前にエスケープ文字（「`\`」）を置く小さなルーチンを書くことだ。

見てのとおり、サーバーがクライアントから送られたものを実行し始めると、セキュリティはかなり大きな問題になる。

**大量のデータを送っているのに、`recv()` すると 536 バイトか 1460 バイトずつしか受信されない。ローカルマシンで動かすと一度に全部受信される。何が起きている？**

[i[MTU]] MTU——物理媒体が扱える最大サイズ——に当たっている。ローカルマシンでは 8K 以上も問題なく扱えるループバックデバイスを使っている。Ethernet ではヘッダ付きで 1500 バイトまでしか扱えないので、その上限にぶつかる。モデム経由で MTU が 576（こちらもヘッダ付き）なら、さらに低い上限に当たる。

まずすべてのデータが送られていることを確認する必要がある（詳細は [`sendall()`](#sendall) 関数の実装を参照）。それが確かになったら、すべて読み終わるまで `recv()` をループで呼ぶ。

`recv()` を複数回呼んで完全なパケットを受信する詳細は、[データカプセル化の続き](#sonofdataencap) の節を読んでほしい。

**Windows マシンにいて `fork()` システムコールも `struct sigaction` もない。どうすれば？**

[i[`fork()` function]] どこかにあるなら、コンパイラに同梱されている POSIX ライブラリの中だろう。Windows マシンを持っていないので正確な答えは言えないが、Microsoft には POSIX 互換レイヤーがあって、そこに `fork()` があるはずだ。（`sigaction` もかもしれない。）

VC++ に付属のヘルプで「fork」や「POSIX」を検索して、手がかりがないか見てほしい。

それでもダメなら、`fork()`／`sigaction` 関連は捨てて、Win32 相当の [i[`CreateProcess()` function]] `CreateProcess()` に置き換える。`CreateProcess()` の使い方は知らない——引数が山ほどあるが、VC++ のドキュメントに載っているはずだ。

[[book-pagebreak]]

**[i[Firewall]] ファイアウォールの内側にいる——外側の人に IP アドレスを知らせてマシンに接続してもらうには？**

残念ながら、ファイアウォールの目的は外側から内側のマシンへの接続を防ぐことなので、それを許すのは基本的にセキュリティ違反とみなされる。

すべてが失われたわけではない。1つは、マスカレードや NAT などをしているファイアウォールなら、しばしば `connect()` で越えられることがある。プログラムは常に自分から接続を開始するように設計すれば問題ない。

[i[Firewall-->poking holes in]] それでは不十分なら、sysadmin にファイアウォールに穴を開けてもらい、外から接続できるように頼める。ファイアウォールは NAT ソフトウェア経由でも、プロキシなど経由でも転送できる。

ファイアウォールの穴は軽く扱うものではない。内部ネットワークに悪意ある人を入れないよう注意が必要だ。初心者にとって、ソフトウェアを安全にするのは想像以上に難しい。

sysadmin を私のせいで怒らせないで。`;-)`

**[i[Packet sniffer]] [i[Promiscuous mode]] パケットスニファはどう書く？ Ethernet インターフェースをプロミスキャスモードにするには？**

知らない人のために言うと、ネットワークカードが「プロミスキャスモード」のとき、この特定のマシン宛てだけでなく _すべて_ のパケットを OS に転送する。（ここで言うのは Ethernet 層のアドレスで、IP アドレスではない——ただし Ethernet は IP より下の層なので、実質的にすべての IP アドレスも転送される。詳細は [低レベルの話とネットワーク理論](#lowlevel) の節を参照。）

これがパケットスニファの仕組みの基礎だ。インターフェースをプロミスキャスモードにすると、OS はケーブル上を流れるすべてのパケットを受け取る。そこからデータを読み取れる、何らかのタイプのソケットを持つことになる。

残念ながら答えはプラットフォームによって異なるが、たとえば「windows promiscuous [i[`ioctl()` function]] ioctl」などで Google すれば、おそらくどこかにたどり着く。Linux には [fl[有用そうな Stack Overflow スレッド|https://stackoverflow.com/questions/21323023/]] もある。

**TCP や UDP ソケットにカスタムの [i[Timeout-->setting]] タイムアウト値を設定するには？**

システム次第だ。ネット上で [i[`SO_RCVTIMEO` macro]] `SO_RCVTIMEO` と [i[`SO_SNDTIMEO` macro]] `SO_SNDTIMEO`（[i[`setsockopt()` function]] `setsockopt()` 用）を検索し、システムがその機能をサポートしているか確認してほしい。

Linux の man ページは、代わりに `alarm()` や `setitimer()` を使うことを示唆している。

[[book-pagebreak]]

**どのポートが使えるかはどうやって調べる？「公式」のポート番号リストはある？**

通常は問題にならない。たとえば Web サーバーを書くなら、よく知られたポート 80 を使うのがよい。自分専用の特殊なサーバーなら、ランダム（ただし 1023 より大きい）なポートを選んで試せばよい。

ポートがすでに使われていれば、`bind()` しようとしたときに「Address already in use」エラーになる。別のポートを選ぶ。（設定ファイルかコマンドラインスイッチで代替ポートを指定できるようにするのがよい。）

Internet Assigned Numbers Authority（IANA）が [fl[公式ポート番号リスト|https://www.iana.org/assignments/port-numbers]] を維持している。リストに載っている（1023 より大きい）番号だからといって使えないわけではない。たとえば Id Software の DOOM は「mdqs」（何それ？）と同じポートを使っている。重要なのは、使いたいときに _同じマシン上_ で他の誰もそのポートを使っていないことだけだ。
