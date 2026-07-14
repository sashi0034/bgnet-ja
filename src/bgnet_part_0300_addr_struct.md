# IP アドレス、`struct`、データ操作

ここからはコードの話をします。

その前に、もう少しコード以外の話！ まず [i[IP address]] IP アドレスとポートについて少し整理しておきましょう。それから、ソケット API が IP アドレスなどのデータをどう保持・操作するか話します。


## IP アドレス、バージョン 4 と 6

昔、ベン・ケノービがまだオビ＝ワン・ケノービと呼ばれていた頃、素晴らしいルーティング方式 The Internet Protocol Version 4、通称 [i[IPv4]] IPv4 がありました。アドレスは 4 バイト（別名 4「オクテット」）で、よく「ドット区切りの数字」形式で書きます：`192.0.2.111`。

どこかで見たことがあるでしょう。

実際、この執筆時点では、インターネット上のほぼすべてのサイトが IPv4 を使っています。

オビ＝ワンを含め皆幸せでした。素晴らしい時代——[i[Vint Cerf]] ヴィント・サーフという懐疑論者が IPv4 アドレスが尽きると警告するまで！

（IPv4 終末の到来を警告したことに加え、[i[Vint Cerf]] [flw[Vint Cerf|Vint_Cerf]] はインターネットの父としても有名です。彼の判断に疑問を挟む立場にはいません。）

アドレスが尽きる？ 32 ビット IPv4 には数十億の IP アドレスがあるのに、本当に数十億台のコンピュータがあるのか？

はい。

また、当初はコンピュータが少数で、10 億はとてつもなく大きな数字だと思われていた頃、大組織には数百万の IP アドレスが惜しみなく割り当てられました（Xerox、MIT、Ford、HP、IBM、GE、AT&T、Apple など）。

実際、いくつかの暫定策がなければ、とっくに尽きていたでしょう。

今は、人間一人ひとり、コンピュータ、電卓、電話、パーキングメーター、（なぜなら）子犬まで、すべてに IP アドレスを持たせる時代です。

そこで [i[IPv6]] IPv6 が生まれました。ヴィント・サーフはたぶん不死（たとえ肉体が逝っても、Internet2 の深みで超知能 [flw[ELIZA|ELIZA]]
プログラムとして存在しているかもしれません）なので、次の Internet Protocol でアドレスが足りなければ再び「言ったでしょ」と言われるのは誰も望みません。

これから何が想像できますか？

もっと _たくさん_ アドレスが必要だ、ということ。2 倍でも、10 億倍でも、1000 兆倍でもなく、_7900 万×10 億×1 兆倍_ のアドレス空間が必要だ！ 見せてやる！

「Beej、本当？ 大きな数字は疑いたくなるんだけど」と言うでしょう。32 ビットと 128 ビットの差は 96 ビット増えただけに聞こえるかもしれません。でも、ここでは累乗の話です：32 ビットは約 40 億（2^32^）、128 ビットは約 340 穰×穰×穰（本当に 2^128^）です。宇宙の _星 1 つにつき_ 100 万個の IPv4 インターネット分です。

IPv4 のドット区切りも忘れてください。今は 16 進表記で、2 バイトごとにコロンで区切ります：

``` {.default}
2001:0db8:c9d2:aee5:73e3:934a:a5ae:9551
```

それだけではありません！ ゼロだらけのアドレスは 2 つのコロンの間で圧縮できます。各バイトペアの先頭ゼロも省略できます。例えば次の各ペアは等価です：

``` {.default}
2001:0db8:c9d2:0012:0000:0000:0000:0051
2001:db8:c9d2:12::51

2001:0db8:ab00:0000:0000:0000:0000:0000
2001:db8:ab00::

0000:0000:0000:0000:0000:0000:0000:0001
::1
```

アドレス `::1` は _ループバックアドレス_ です。常に「今動いているこのマシン」を意味します。IPv4 では `127.0.0.1` です。

最後に、IPv6 アドレスの IPv4 互換表記に出会うことがあります。例えば IPv4 アドレス `192.0.2.33` を IPv6 で表すなら「`::ffff:192.0.2.33`」です。

本気の楽しさです。

実に本気すぎて、IPv6 の創設者たちは何穰も何穰ものアドレスを予約用途に切り捨てましたが、まだ十分あります。銀河のすべての惑星の、すべての人、子犬、パーキングメーターに足りるほど。銀河のすべての惑星にパーキングメーターがあるのは、知っている通りです。


### サブネット

管理上、IP アドレスの「このビットまでが _ネットワーク部_、残りが _ホスト部_」と決めることが便利な場合があります。

例えば IPv4 で `192.0.2.12` があり、最初の 3 バイトがネットワーク、最後の 1 バイトがホスト、と言えます。別の言い方では、ネットワーク `192.0.2.0` のホスト `12` です（ホストだったバイトをゼロにした形）。

さらに古い話です！ 準備はいい？ 太古にはアドレスの最初の 1、2、3 バイトがネットワーク部だった「クラス」がありました。ネットワーク 1 バイト・ホスト 3 バイトなら、24 ビット分（約 1600 万）のホストを載せられました。これが「クラス A」ネットワーク。反対端はネットワーク 3 バイト・ホスト 1 バイトの「クラス C」（256 ホスト、うち数個は予約）。

ご覧の通り、クラス A は少数、クラス C は大量、クラス B がその中間でした。

IP アドレスのネットワーク部は _ネットマスク_ で表し、IP アドレスとビット単位 AND してネットワーク番号を取り出します。ネットマスクは `255.255.255.0` のような形が多いです。（例：そのネットマスクで IP が `192.0.2.12` なら、ネットワークは `192.0.2.12` AND `255.255.255.0` で `192.0.2.0`。）

残念ながら、インターネットの需要には粗すぎました。クラス C ネットワークが急速に尽き、クラス A はとっくにないので、聞かないでください。対策として、ネットマスクは 8、16、24 ビットに限らず任意のビット数にできました。例えば `255.255.255.252` はネットワーク 30 ビット・ホスト 2 ビットで、4 ホストのネットワークです。（ネットマスクは _常に_ 1 の連続のあと 0 の連続です。）

`255.192.0.0` のような長い数字列は扱いにくいです。何ビットか直感がわかないし、コンパクトでもありません。そこで新しい書き方：IP アドレスの後にスラッシュとネットワークビット数（10 進）を付けます。例：`192.0.2.12/30`。

IPv6 なら `2001:db8::/32` や `2001:db8:5413:4028::9db9/64` などです。


### ポート番号

覚えているでしょう、先に [レイヤード・ネットワーク・モデル](#lowlevel) で Internet Layer（IP）と Host-to-Host Transport Layer（TCP と UDP）が分かれている、と述べました。次の段落に進む前に復習しておいてください。

IP アドレス（IP 層が使う）に加え、TCP（ストリームソケット）と、偶然にも UDP（データグラムソケット）が使う _もう 1 つのアドレス_ があります。_ポート番号_ です。接続のローカルアドレスのような 16 ビットの番号です。

IP アドレスをホテルの住所、ポート番号を部屋番号と考えてください。まあまあの比喩です。後で自動車業界版を考えるかもしれません。

1 つの IP アドレスのマシンで、受信メールと Web の両方を扱うには、どう区別する？

インターネット上のサービスにはそれぞれ well-known なポート番号があります。[fl[IANA の巨大ポート
リスト|https://www.iana.org/assignments/port-numbers]] や、Unix なら `/etc/services` で一覧できます。HTTP（Web）は 80、telnet は 23、SMTP は 25、ゲーム [fl[DOOM|https://en.wikipedia.org/wiki/Doom_%281993_video_game%29]] は 666 など。1024 未満のポートは特別扱いで、多くの OS では特権が必要です。

以上、だいたいこんなところです！


## バイト順

[i[Byte ordering]] 王国の命令により！ バイト順は 2 種類——以降、凡庸と崇高と呼ぶ！

冗談ですが、一方は本当にもう一方より優れています。`:-)`

はっきり言うと、コンピュータがこっそりバイトを逆順で格納している _かもしれません_。知らなかったでしょう。

インターネット界では、2 バイトの 16 進数 `b34f` を表すなら、連続 2 バイト `b3` のあと `4f` で格納することに概ね合意しています。理にかなっていますし、[fl[Wilford
Brimley|https://en.wikipedia.org/wiki/Wilford_Brimley]] なら Right Thing To Do と言うでしょう。この big end 先の格納を _ビッグエンディアン_ と呼びます。

残念ながら、世界に散在する _少数_ のコンピュータ——Intel または Intel 互換プロセッサ搭載機——はバイトを逆に格納し、`b34f` は `4f` のあと `b3` になります。これを _リトルエンディアン_ と呼びます。

用語はまだ続きます！ よりまともな _ビッグエンディアン_ は、ネットワーク関係者が好むので _ネットワーク・バイト順_ とも呼ばれます。

コンピュータは _ホスト・バイト順_ で数値を格納します。Intel 80x86 ならホスト・バイト順はリトルエンディアン。Motorola 68k ならビッグエンディアン。PowerPC なら……機種による！

パケット組み立てやデータ構造の充填では、2 バイト・4 バイトの数値をネットワーク・バイト順にする必要がよくあります。ホスト・バイト順がわからなくても？

朗報！ ホスト・バイト順は正しくないと仮定し、常にネットワーク・バイト順に変換する関数を通せばよいのです。必要なら変換してくれるので、エンディアンの異なるマシン間でも移植性が保てます。

さて、変換できる型は `short`（2 バイト）と `long`（4 バイト）の 2 種類です。`unsigned` 版にも使えます。例：`short` をホスト・バイト順からネットワーク・バイト順へ。「h」= host、「to」、「n」= network、「s」= short：h-to-n-s、つまり `htons()`（「Host to Network Short」と読む）。

簡単すぎる……

「n」「h」「s」「l」の組み合わせは、本当に愚かなものを除けば使えます。例えば `stolh()`（「Short to Long Host」）は _ない_ —— このパーティでは。あるのは：

[[book-pagebreak]]

| 関数  | 説明                   |
|-----------|-------------------------------|
| [i[`htons()` function]]`htons()` | `h`ost `to` `n`etwork `s`hort |
| [i[`htonl()` function]]`htonl()` | `h`ost `to` `n`etwork `l`ong  |
| [i[`ntohs()` function]]`ntohs()` | `n`etwork `to` `h`ost `s`hort |
| [i[`ntohl()` function]]`ntohl()` | `n`etwork `to` `h`ost `l`ong  |

基本的に、送る前にネットワーク・バイト順へ、受け取ったらホスト・バイト順へ変換します。

ソケット API に標準の 64 ビット版はありませんが、[`htons()` リファレンスページ](#htonsman) で他の選択肢に触れます。浮動小数点なら下の [Serialization](#serialization) 節を参照。

特に断りがない限り、この文書の数値はホスト・バイト順とします。


## `struct` {#structs}

ようやくここまで来ました。プログラミングの話です。この節ではソケットインターフェースの各種データ型を扱います。いくつかは本当にわかりにくいです。

まず簡単なもの：[i[Socket descriptor]] ソケット記述子。型は次のとおり：

```{.c}
int
```

普通の `int` です。

ここから変わってきます。読み進めてください。

My First Struct™——`struct addrinfo`。[i[`struct addrinfo` type]] 比較的新しい構造体で、後続のソケットアドレス構造体の準備に使います。ホスト名・サービス名のルックアップにも使います。実際の使用例で理解が深まりますが、接続を張るとき最初に呼ぶものの 1 つ、と覚えておいてください。

```{.c}
struct addrinfo {
    int              ai_flags;     // AI_PASSIVE, AI_CANONNAME, etc.
    int              ai_family;    // AF_INET, AF_INET6, AF_UNSPEC
    int              ai_socktype;  // SOCK_STREAM, SOCK_DGRAM
    int              ai_protocol;  // use 0 for "any"
    size_t           ai_addrlen;   // size of ai_addr in bytes
    struct sockaddr *ai_addr;      // struct sockaddr_in or _in6
    char            *ai_canonname; // full canonical hostname

    struct addrinfo *ai_next;      // linked list, next node
};
```

この struct を少し埋めて [i[`getaddrinfo()`
function]] `getaddrinfo()` を呼びます。必要な情報が入った新しい連結リストへのポインタが返ります。

`ai_family` で IPv4 または IPv6 を強制できます。`AF_UNSPEC` のままならどちらでも。IP バージョンに依存しないコードが書けて便利です。

連結リストであることに注意：`ai_next` が次の要素——選択肢が複数ある場合があります。動いた最初の結果を使うのが普通ですが、要件は人それぞれ。全部は知りません！

`struct addrinfo` の `ai_addr` は [i[`struct sockaddr` type]] `struct sockaddr` へのポインタです。IP アドレス構造体の中身の詳細に入るところです。

これらの構造体に書き込む必要は通常ありません。`getaddrinfo()` で `struct addrinfo` を埋めてもらうだけで足りることが多いです。ただし値を取り出すには中を覗く必要があるので、ここで紹介します。

（`struct addrinfo` 以前のコードは手作業で詰めていたので、IPv4 コードが世の中に大量に残っています。このガイドの旧版など。）

`struct` には IPv4 専用、IPv6 専用、両方対応があります。どれがどれか注記します。

とにかく `struct sockaddr` は多種のソケットアドレス情報を保持します。

```{.c}
struct sockaddr {
    unsigned short    sa_family;    // address family, AF_xxx
    char              sa_data[14];  // 14 bytes of protocol address
}; 
```

`sa_family` はいろいろあり得ますが、この文書では [i[`AF_INET`
macro]] `AF_INET`（IPv4）か [i[`AF_INET6` macro]] `AF_INET6`（IPv6）です。`sa_data` に宛先アドレスとポート番号があります。手で `sa_data` に詰めるのは面倒なので、

`struct sockaddr` 向けに並行構造体が作られました：[i[`struct sockaddr` type]] `struct sockaddr_in`（「in」= Internet）、IPv4 用です。

_重要な_ 点：`struct sockaddr_in` へのポインタは `struct sockaddr` へのポインタにキャストでき、その逆も可能です。`connect()` は `struct sockaddr*` を欲しますが、最後にキャストすれば `struct sockaddr_in` を使えます！

```{.c}
// (IPv4 only--see struct sockaddr_in6 for IPv6)

struct sockaddr_in {
    short int          sin_family;  // Address family, AF_INET
    unsigned short int sin_port;    // Port number
    struct in_addr     sin_addr;    // Internet address
    unsigned char      sin_zero[8]; // Same size as struct sockaddr
};
```

ソケットアドレスの各要素を参照しやすい構造です。`sin_zero`（`struct sockaddr` と同じ長さにするパディング）は `memset()` でゼロにします。`sin_family` は `struct sockaddr` の `sa_family` に対応し、`AF_INET` に設定します。`sin_port` は [i[Byte ordering]] _ネットワーク・バイト順_（[i[`htons()` function]] `htons()` を使う！）である必要があります。

もう一段深く！ `sin_addr` は `struct in_addr` です。何者？ 史上最恐の union の 1 つでした：

```{.c}
// (IPv4 only--see struct in6_addr for IPv6)

// Internet address (a structure for historical reasons)
struct in_addr {
    uint32_t s_addr; // that's a 32-bit int (4 bytes)
};
```

おお！ _かつて_ は union でしたが、今はそうでもありません。良かった。`ina` を `struct
sockaddr_in` 型と宣言すれば、`ina.sin_addr.s_addr` が 4 バイトの IP アドレス（ネットワーク・バイト順）を参照します。システムが `struct in_addr` に union を使っていても、上と同じ方法で 4 バイト IP を参照できます（`#define` のおかげ）。

[i[IPv6]] IPv6 も同様の `struct` があります：

```{.c}
// (IPv6 only--see struct sockaddr_in and struct in_addr for IPv4)

struct sockaddr_in6 {
    u_int16_t       sin6_family;   // address family, AF_INET6
    u_int16_t       sin6_port;     // port, Network Byte Order
    u_int32_t       sin6_flowinfo; // IPv6 flow information
    struct in6_addr sin6_addr;     // IPv6 address
    u_int32_t       sin6_scope_id; // Scope ID
};

struct in6_addr {
    unsigned char   s6_addr[16];   // IPv6 address
};
```

IPv6 も IPv6 アドレスとポート番号を持ち、IPv4 も IPv4 アドレスとポート番号を持つ、という点は同じです。

IPv6 の flow information や Scope ID フィールドは今は触れません……入門ガイドなので。`:-)`

最後に、`struct
sockaddr_storage` というシンプルな構造体。IPv4 と IPv6 の両方を載せられる十分な大きさです。呼び出しによって `struct sockaddr` が IPv4 か IPv6 で埋まるか事前にわからない場合、この大きめの並行構造体を渡して、必要な型にキャストします：

```{.c}
struct sockaddr_storage {
    sa_family_t  ss_family;     // address family

    // all this is padding, implementation specific, ignore it:
    char      __ss_pad1[_SS_PAD1SIZE];
    int64_t   __ss_align;
    char      __ss_pad2[_SS_PAD2SIZE];
};
```

重要なのは `ss_family` でアドレスファミリがわかること——`AF_INET` か `AF_INET6`（IPv4 か IPv6）か確認し、`struct sockaddr_in` か `struct sockaddr_in6` にキャストすればよい、ということです。


## IP アドレス、其の弐

幸い、[i[IP address]] IP アドレスを操作する関数がたくさんあります。手計算で `long` に `<<` で詰める必要はありません。

`struct sockaddr_in ina` があり、IP アドレス「`10.12.110.57`」または「`2001:db8:63b3:1::3490`」を入れたいとします。[i[`inet_pton()`
function]] `inet_pton()` が、ドット区切り表記の IP を `AF_INET` なら `struct in_addr`、`AF_INET6` なら `struct in6_addr` に変換します。（「`pton`」= presentation to network——「printable to network」と覚えてもよい。）IPv4 と IPv6 の変換例：

```{.c}
struct sockaddr_in sa;   // IPv4
struct sockaddr_in6 sa6; // IPv6

inet_pton(AF_INET, "10.12.110.57", &(sa.sin_addr));
inet_pton(AF_INET6, "2001:db8:63b3:1::3490", &(sa6.sin6_addr));
```

（補足：昔は [i[`inet_addr()` function]] `inet_addr()` や [i[`inet_aton()` function]] `inet_aton()` を使いました。今は obsolete で IPv6 非対応です。）

上のスニペットはエラーチェックがなくあまり堅牢ではありません。`inet_pton()` はエラーで `-1`、アドレスが不正なら `0` を返します。使う前に結果が 0 より大きいことを確認してください。

文字列 IP をバイナリに変換できました。逆は？ `struct in_addr` をドット区切りで表示したい（`struct in6_addr` なら「hex-and-colons」形式）場合、[i[`inet_ntop()` function]] `inet_ntop()`（「ntop」= network to presentation——「network to printable」でも可）を使います：

```{.c .numberLines}
// IPv4:

char ip4[INET_ADDRSTRLEN];  // space to hold the IPv4 string
struct sockaddr_in sa;      // pretend this is loaded with something

inet_ntop(AF_INET, &(sa.sin_addr), ip4, INET_ADDRSTRLEN);

printf("The IPv4 address is: %s\n", ip4);


// IPv6:

char ip6[INET6_ADDRSTRLEN]; // space to hold the IPv6 string
struct sockaddr_in6 sa6;    // pretend this is loaded with something

inet_ntop(AF_INET6, &(sa6.sin6_addr), ip6, INET6_ADDRSTRLEN);

printf("The address is: %s\n", ip6);
```

呼び出し時はアドレス型（IPv4 か IPv6）、アドレス、結果文字列へのポインタ、その最大長を渡します。（最大 IPv4/IPv6 文字列長を保持するマクロ：`INET_ADDRSTRLEN` と `INET6_ADDRSTRLEN`。）

（もう 1 つ：昔は [i[`inet_ntoa()` function]] `inet_ntoa()` で変換していました。こちらも obsolete で IPv6 非対応。）

これらの関数は数値 IP のみ——「`www.example.com`」のようなホスト名の DNS ルックアップはしません。それは後述の `getaddrinfo()` です。


### プライベート（または非接続）ネットワーク

[i[Private network]] 多くの場所では [i[Firewall]] ファイアウォールがネットワークを外の世界から隠して保護しています。ファイアウォールは「内部」IP を「外部」（世の中が知る）IP に _Network Address Translation_、通称 [i[NAT]] NAT で変換することがよくあります。

不安になってきた？ 「この変な話、どこに向かうんだ？」

リラックスして、アルコール入り（なしでも）飲み物を。初心者なら NAT を意識する必要はほぼなく、透過的に処理されます。ただ、ファイアウォールの向こうのネットワークで見かける番号に混乱しないよう、触れておきました。

例：自宅にファイアウォールがあります。DSL 会社から静的 IPv4 を 2 つ割り当てられているのに、LAN には 7 台の PC があります。どう可能？ 2 台が同じ IP を共有したら、データの行き先がわからない！

答え：同じ IP は共有していません。2400 万個の IP が割り当てられたプライベートネットワーク上にあり、外から見ればすべて私用です。何が起きているか：

リモートにログインすると、ISP が割り当てた公開 IP `192.0.2.33` からログインしたと表示されます。ローカルマシンに IP を聞くと `10.0.0.5` と答えます。誰が IP を変換している？ その通り、ファイアウォール！ NAT です！

`10.x.x.x` は、完全に切り離されたネットワークか、ファイアウォールの内側専用の予約ネットワークの 1 つです。使えるプライベート番号の詳細は [flrfc[RFC 1918|1918]]。よく見るのは [i[`10.x.x.x`]] `10.x.x.x` と [i[`192.168.x.x`]]
`192.168.x.x`（`x` はだいたい 0–255）。あまり見ないのは `172.y.x.x`（`y` は 16–31）。

NAT するファイアウォールの内側は、これらの予約ネットワークである _必要は_ ありませんが、よくそうなっています。

（豆知識！ 私の外部 IP は本当は `192.0.2.33` ではありません。`192.0.2.x` ネットワークは、このガイドのようなドキュメント用の架空「実」IP 用に予約されています！）

[i[IPv6]] IPv6 にも、ある意味プライベートネットワークがあります。`fdXX:`（将来は `fcXX:` かも、[flrfc[RFC 4193|4193]]）で始まります。NAT と IPv6 は一般に混ぜません（IPv6–IPv4 ゲートウェイはこの文書の範囲外）——理論上はアドレスが十分で NAT は不要になるはずです。外にルーティングしないネットワークで自分用に割り当てるなら、この方法です。
