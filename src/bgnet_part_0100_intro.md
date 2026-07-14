# はじめに
<!--
Beej's Guide to Network Programming book source

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!--
	History:

	2.3.2:		socket man page
	2.3.3:		sockaddr_in man page
	2.3.4:		bind, listen man page
	2.3.5:		connect man page
	2.3.6:		listen, perror man page
	2.3.7:		errno man page
	2.3.8:		htonl etc man page
	2.3.9:		close man page, expanded man page leader
	2.3.10:		inet_ntoa, setsockopt man pages
	2.3.11:		getpeername man page
	2.3.12:		send/sendto man pages
	2.3.13:		shutdown man pages
	2.3.14:		gethostname man pages, fix inet_aton links
	2.3.15:		fcntl man page
	2.3.16:		recv/recvfrom man page
	2.3.17:		gethostbyname/gethostbyaddr man page
	2.3.18:		changed GET / to GET / HTTP/1.0
	2.3.19:		added select() man page
	2.3.20:		added poll() man page
	2.3.21:		section on NAT and reserved networks
	2.3.22:		typo fixes in sects "man" and "privnet"
	2.3.23:		added broadcast packets section
	2.3.24:		manpage prototype changed to code, subtitle moved out of title
	2.4.0:		big overhaul, serialization stuff
	2.4.1:		minor text changes in intro
	2.4.2:		changed all sizeofs to use variable names instead of types
	2.4.3:		fix myaddr->my_addr in listener.c, sockaddr_inman example
	2.4.4:		fix myaddr->my_addr in server.c
	2.4.5:		fix 14->18 in son of data encap
	3.0.0:		IPv6 overhaul
	3.0.1:		sa-to-sa6 typo fix
	3.0.2:		typo fixes
	3.0.3:		typo fixes
	3.0.4:		cut-n-paste errors, selectserver hints fix
	3.0.5:		typo fixes
	3.0.6:		typo fixes
	3.0.7:		typo fixes, added front matter
	3.0.8:		getpeername() code fixes
	3.0.9:		getpeername() code fixes, this time fer sure
	3.0.10:		bind() man page code fix, comment changes
	3.0.11:		socket syscall section code fix, comment changes
	3.0.12:		typos in "IP Addresses, structs, and Data Munging"
	3.0.13:		amp removals, note about errno and multithreading
	3.0.14:		type changes to listener.c, pack2.c
	3.0.15:		fix inet_pton example
	3.0.16:		fix simple server output, optlen in getsockopt man page
	3.0.17:		fix small typo
	3.0.18:		reverse perror and close calls in getaddrinfo
	3.0.19:		add notes about O_NONBLOCK with select() under Linux
	3.0.20:		fix missing .fd in poll() example
	3.0.21:		change sizeof(int) to sizeof yes
    3.0.22:     C99 updates, bug fixes, markdown
    3.0.23:     Book reference and URL updates
    3.1.0:      Section on poll()
    3.1.1:      Add WSL note, telnot
    3.1.2:      pollserver.c bugfix
    3.1.3:      Fix freeaddrinfo memleak
    3.1.4:      Fix accept example header files
    3.1.5:      Fix dgram AF_UNSPEC
-->

<!-- prevent hyphenation of the following words: -->
[nh[strtol]]
[nh[sprintf]]
[nh[accept]]
[nh[bind]]
[nh[connect]]
[nh[close]]
[nh[getaddrinfo]]
[nh[freeaddrinfo]]
<!--
Don't know how to make this work with underscores. I love
you, Knuth, but... daaahm.

[nh[gai_strerr]]
-->
[nh[gethostname]]
[nh[gethostbyname]]
[nh[gethostbyaddr]]
[nh[getnameinfo]]
[nh[getpeername]]
[nh[errno]]
[nh[fcntl]]
[nh[htons]]
[nh[htonl]]
[nh[ntohs]]
[nh[ntohl]]
<!--
[nh[inet_ntoa]]
[nh[inet_aton]]
[nh[inet_addr]]
[nh[inet_ntop]]
[nh[inet_pton]]
-->
[nh[listen]]
[nh[perror]]
[nh[strerror]]
[nh[poll]]
[nh[recv]]
[nh[recvfrom]]
[nh[select]]
[nh[setsockopt]]
[nh[getsockopt]]
[nh[send]]
[nh[sendto]]
[nh[shutdown]]
[nh[socket]]
[nh[struct]]
[nh[sockaddr]]
<!--
[nh[sockaddr_in]]
[nh[in_addr]]
[nh[sockaddr_in6]]
[nh[in6_addr]]
-->
[nh[hostent]]
[nh[addrinfo]]
[nh[closesocket]]

やあ！ソケット（socket）プログラミングで困っていませんか？`man` ページだけでは、ちょっと難しすぎて理解しきれない？クールなインターネットプログラミングをやりたいのに、`struct` の山をかき分けながら、`connect()` の前に `bind()` を呼ぶ必要があるのかどうか、なんてことを調べる時間がない、とか。

まあ、いい知らせがあるよ！この面倒な作業は、もう僕がやっておいた。しかも、みんなに情報を共有したくてうずうずしているところだ！来るところ正解だ。このドキュメントが、平均的に腕の立つ C プログラマに、このネットワークのノイズを掴むための武器を与えてくれるはずだ。

それからこれも見て：未来（ギリギリ間に合ったけど！）にようやく追いついて、ガイドを IPv6 向けに更新した！楽しんで！

## 対象読者

このドキュメントは完全なリファレンスではなく、チュートリアルとして書かれている。ソケットプログラミングを始めたばかりで、足がかりを探している人が読むのに、おそらく一番ちょうどいい。決して、ソケットプログラミングの完全網羅ガイド、なんてものではない。

とはいえ、これで `man` ページがだんだん意味をなしてくるようになれば、十分かもしれない…… `:-)`


## プラットフォームとコンパイラ

このドキュメントに含まれるコードは、Linux PC 上で Gnu の [i[Compilers-->GCC]] `gcc` コンパイラを使ってコンパイルされた。ただし、`gcc` を使うほとんどすべてのプラットフォームでビルドできるはずだ。もちろん、Windows 向けにプログラミングしている場合は別——下の [Windows プログラミングに関する節](#windows) を参照してほしい。


## 公式ホームページと書籍の購入

このドキュメントの公式の場所は次のとおりです：

* [`https://beej.us/guide/bgnet/`](https://beej.us/guide/bgnet/)

日本語版はこちらです：

* [`https://sashi0034.github.io/bgnet-ja/`](https://sashi0034.github.io/bgnet-ja/)

そこでは、サンプルコードや、ガイドの各言語への翻訳も見つかる。

きれいに製本された印刷版（本、と呼ぶ人もいる）を買いたいなら、こちらへ：

* [`https://beej.us/guide/url/bgbuy`](https://beej.us/guide/url/bgbuy)

購入してくれるとうれしい。ドキュメント執筆という生き方を続ける助けになるから！


## Solaris/SunOS/illumos プログラマ向け注記 {#solaris}

[i[Solaris]] Solaris 系や [i[SunOS]] SunOS 向けにコンパイルするときは、適切なライブラリをリンクするために、いくつか追加のコマンドラインスイッチを指定する必要がある。これを行うには、コンパイルコマンドの末尾に "`-lnsl -lsocket -lresolv`" を追加するだけだ。例えばこんな感じ：

```
$ cc -o server server.c -lnsl -lsocket -lresolv
```

それでもエラーが出るなら、コマンドラインの末尾に `-lxnet` をさらに足してみてもいい。正確に何をするのかは僕も知らないけど、必要とする人がいるらしい。

問題が出る可能性があるもう一つの場所は、`setsockopt()` の呼び出しだ。プロトタイプが僕の Linux ボックス上のものと異なるので、次の代わりに：

```{.c}
int yes=1;
```

こう書く：

```{.c}
char yes='1';
```

Sun マシンを持っていないので、上記の情報はテストしていない——メールで教えてもらった内容をそのまま載せているだけだ。


## Windows プログラマ向け注記 {#windows}

このガイドのこの地点では、歴史的に、僕は [i[Windows]] Windows をけなしてきた。単にあまり好きじゃないからだ。でも、その後 Windows も Microsoft（会社として）もだいぶ良くなった。Windows 10 と WSL（下記）を組み合わせると、実際にまともな OS になる。文句を言うことも、そんなに多くない。

まあ、少しは——例えば、僕はこれを（2025 年に）Windows 10 が入っていた 2015 年製ノート PC で書いている。いつか遅くなりすぎて、Linux を入れた。それ以来ずっと使っている。

でも今度は Windows 11 がある。どうやら Windows 10 よりもハードウェアに余裕が必要らしい。僕はそれが好きじゃない。OS はできるだけ目立たず、追加の出費を強いるべきじゃない。余分な CPU パワーはアプリのためであって、OS のためじゃない！それに、Microsoft はあなたが何を望んでいるか知っている。望んでいるのは、もっと広告だ！そうでしょ？OS の中に！それが恋しかったんじゃない？Windows 11 なら手に入るよ。

だから……それでも [i[Linux]]
[fl[Linux|https://www.linux.com/]]、[i[BSD]] [fl[BSD|https://bsd.org/]]、
[i[illumos]] [fl[illumos|https://www.illumos.org/]] など、Windows の代わりに Unix 系のどれかを試すことを勧める。

この説教台、どこから来たんだ？

でも、好きなものは好きなんだろう。Windows 派のみなさんも喜んでくれると思う——この情報は、いくつか小さな変更を除けば、Windows にも概ね当てはまる。

強く検討してほしいのが [i[WSL]] [i[Windows
Subsystem For Linux]] [fl[Windows Subsystem for
Linux|https://learn.microsoft.com/en-us/windows/wsl/]] だ。これは基本的に、Windows 10 上に Linux の VM みたいなものを入れられる。それでも間違いなく環境が整うし、このプログラムをそのままビルドして実行できる。

もう一つの方法は [i[Cygwin]]
[fl[Cygwin|https://cygwin.com/]] をインストールすることだ。Windows 向けの Unix ツール集だ。噂では、これを入れるとここにあるプログラムがすべて修正なしでコンパイルできるらしいけど、僕は試したことがない。

Pure Windows Way でやりたい人もいるだろう。度胸があるね。やることはこれだ：すぐ Unix を手に入れろ！……冗談だよ。最近は Windows にも（少し）優しくするはずなんだけど……

わかった、わかった。本題に入るよ。

[i[Winsock]]

やることはこうだ：まず、ここで言及するシステムヘッダファイルは、だいたい無視してほしい。代わりに、次をインクルードする：

```{.c}
#include <winsock2.h>
#include <ws2tcpip.h>
```

`winsock2` は Windows ソケットライブラリの「新しい」（1994 年頃）バージョンだ。

残念ながら、`windows.h` をインクルードすると、古い `winsock.h`（バージョン 1）ヘッダが自動的に引き込まれ、`winsock2.h` と衝突する！楽しいね。

だから `windows.h` をインクルードする必要があるなら、古いヘッダをインクルード*しない*ようにマクロを定義する必要がある：

```{.c}
#define WIN32_LEAN_AND_MEAN  // Say this...

#include <windows.h>         // And now we can include that.
#include <winsock2.h>        // And this.
```

待って！ソケットライブラリで何かする前に、[i[`WSAStartup()` function]]
`WSAStartup()` を呼ぶ必要もある。この関数に使いたい Winsock のバージョン（例：2.2）を渡す。そして結果を確認して、そのバージョンが使えることを確かめる。

そのコードはだいたいこんな感じ：

```{.c .numberLines}
#include <winsock2.h>

{
    WSADATA wsaData;

    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        fprintf(stderr, "WSAStartup failed.\n");
        exit(1);
    }

    if (LOBYTE(wsaData.wVersion) != 2 ||
        HIBYTE(wsaData.wVersion) != 2)
    {
        fprintf(stderr,"Version 2.2 of Winsock not available.\n");
        WSACleanup();
        exit(2);
    }
```

そこにある [i[`WSACleanup()` function]] `WSACleanup()` の呼び出しに注目。Winsock ライブラリを使い終わったときに呼ぶ関数だ。

コンパイラに Winsock ライブラリのリンクも指示する必要がある。Winsock 2 では `ws2_32.lib` と呼ばれる。VC++ では、`Project` メニューの `Settings...` からできる。`Link` タブをクリックして、"Object/library modules" というボックスを探す。そこに "ws2_32.lib"（または好みの lib）を追加する。

……らしい。

それができれば、このチュートリアルの残りの例は、いくつかの例外を除いて、概ねそのまま使える。一点、ソケットを閉じるのに `close()` は使えない——代わりに [i[`closesocket()`
function]] `closesocket()` を使う必要がある。また、[i[`select()` function]]
`select()` はファイル記述子（`stdin` の `0` など）ではなく、ソケット記述子にしか使えない。

使えるソケットクラスもある。[i[`CSocket` class]]
[`CSocket`](https://learn.microsoft.com/en-us/cpp/mfc/reference/csocket-class?view=msvc-170)
詳しくはコンパイラのヘルプページを参照してほしい。

Winsock の詳細は、[Microsoft の公式ページ](https://learn.microsoft.com/en-us/windows/win32/winsock/windows-sockets-start-page-2)を参照してほしい。

最後に、Windows には [i[`fork()` function]] `fork()`
システムコールがない、と聞いている。残念ながら、僕の例のいくつかで使っている。POSIX ライブラリをリンクする必要があるのかもしれないし、代わりに [i[`CreateProcess()` function]] `CreateProcess()` を使うこともできる。`fork()` は引数を取らないが、`CreateProcess()` はだいたい 48 億個の引数を取る。それが厳しければ、[i[`CreateThread()`
function]] `CreateThread()` の方が少し飲み込みやすい……残念ながら、マルチスレッドの話はこのドキュメントの範囲外だ。書けることには限りがあるんだ、わかるだろ？

さらに最後に、Steven Mitchell が [fl[例のいくつかを Winsock 向けに移植|https://www.tallyhawk.net/WinsockExamples/]] している。そちらもチェックしてみてほしい。


## メールについて

[i[Emailing Beej]] メールでの質問には、だいたい対応できるので、気軽に書いてほしい。ただし、返信を保証するものではない。結構忙しい生活を送っていて、質問に答えられないときもある。そのときは、たいていメッセージを削除する。個人的なことじゃない——必要な詳しい回答を書く時間が、どうしてもないだけだ。

ルールとして、質問が複雑になるほど、返信の可能性は低くなる。メールする前に質問を絞り込み、関連情報（プラットフォーム、コンパイラ、出ているエラーメッセージ、トラブルシュートに役立ちそうなことなど）を必ず含めてくれれば、返信されやすくなる。さらにヒントが欲しければ、ESR の [fl[賢く質問する方法|http://www.catb.org/~esr/faqs/smart-questions.html]] を読んでほしい。

返事がなければ、もう少し自分でいじって、答えを探してみて。それでも見つからなければ、見つかった情報を添えてもう一度書いてくれ。そうすれば、助けられるかもしれない。

書き方についてうるさく言ったあとで、ガイドが長年受けてきた称賛には*本当に*感謝している、と伝えたい。士気を上げてくれるし、良い目的に使われていると聞くとうれしい！ `:-)` ありがとう！


## ミラーサイト

[i[Mirroring the Guide]] このサイトを公開・非公開を問わずミラーしてもらって構わない。公開ミラーにしてメインページからリンクしてほしい場合は、[`beej@beej.us`](mailto:beej@beej.us) まで連絡してほしい。


## 翻訳者向け注記

[i[Translating the Guide]] ガイドを別の言語に翻訳したい場合は、[`beej@beej.us`](mailto:beej@beej.us) に連絡してくれ。メインページから翻訳へのリンクを張る。翻訳に自分の名前と連絡先を載せても構わない。

**日本語訳について：** 本日本語訳は GitHub Pages（[`https://sashi0034.github.io/bgnet-ja/`](https://sashi0034.github.io/bgnet-ja/)）で公開されている。原文の著作権は Brian "Beej Jorgensen" Hall 氏に帰属する。

このソース Markdown ドキュメントは UTF-8 エンコーディングを使用している。

下記の [著作権、配布、および法的事項](#legal) 節のライセンス制限に注意してほしい。

翻訳をホスティングしてほしい場合は、声をかけてくれ。自分でホストする場合も、リンクを張る。どちらでも構わない。


## 著作権、配布、および法的事項 {#legal}

Beej's Guide to Network Programming の著作権 © 2019 Brian "Beej
Jorgensen" Hall.

以下のソースコードおよび翻訳に関する特定の例外を除き、この作品は Creative Commons Attribution- Noncommercial-
No Derivative Works 3.0 License の下でライセンスされている。このライセンスの写しは、次の URL で閲覧できる：

[`https://creativecommons.org/licenses/by-nc-nd/3.0/`](https://creativecommons.org/licenses/by-nc-nd/3.0/)

または Creative Commons, 171 Second Street, Suite 300, San
Francisco, California, 94105, USA あてに手紙を送ること。

ライセンスの「No Derivative Works（改変禁止）」部分に対する一つの特定の例外は次のとおり：このガイドは、翻訳が正確であり、ガイド全体が再印刷される限り、任意の言語に自由に翻訳できる。翻訳にも、原文と同じライセンス制限が適用される。翻訳には、翻訳者の名前と連絡先を含めてもよい。

このドキュメントに示されている C ソースコードは、パブリックドメインに提供され、いかなるライセンス制限もまったくない。

教育者は、学生にこのガイドのコピーを推薦または提供することを自由に行える。

書面による双方の合意がない限り、著者は作品を現状のまま提供し、作品に関する明示的、黙示的、法定その他いかなる種類の表明または保証（タイトル、商品性、特定目的への適合性、非侵害、または潜在的その他の欠陥の不存在、正確性、またはエラーの有無（発見可能かどうかを問わず）を含むがこれらに限定されない）も行わない。

適用法で要求される範囲を除き、著者がそのような損害の可能性を知らされていた場合でも、いかなる法的理論においても、作品の使用から生じる特別、付随、結果的、懲罰的または模範的損害について、著者はあなたに対して責任を負わない。

詳細は [`beej@beej.us`](mailto:beej@beej.us) まで連絡してほしい。


## 献辞

このガイドの執筆を手伝ってくれた、過去と未来のみなさんに感謝する。そして、ガイドの作成に使っている Free ソフトウェアやパッケージを生み出してくれた人たちにも：GNU、Linux、Slackware、vim、Python、Inkscape、pandoc、その他多数。そして最後に、改善提案や励ましの言葉を寄せてくれた、文字通り何千人もの方々に、心から感謝する。

このガイドを、コンピュータの世界で僕の最大のヒーロー兼インスピレーションの源である Donald Knuth、Bruce Schneier、W. Richard Stevens、The Woz、読者のみなさん、そして Free および Open Source ソフトウェアコミュニティ全体に捧げる。


## 出版情報

この本は、GNU ツールを載せた Arch Linux マシン上で vim エディタを使い、Markdown で書かれている。表紙の「アート」と図は Inkscape で作成した。Markdown は Python、Pandoc、XeLaTeX によって HTML および LaTeX/PDF に変換され、Liberation フォントを使用している。ツールチェーンは 100% Free および Open Source ソフトウェアで構成されている。
