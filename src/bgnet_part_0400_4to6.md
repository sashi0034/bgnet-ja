# IPv4 から IPv6 へのジャンプ

[i[IPv6]]

でもコードを IPv6 対応にするには何を変えればいいか、今すぐ知りたいんだろ？

わかった！わかった！

ここにあることのほとんどは、上ですでに説明した内容の短縮版だ——せっかちな人向けに。（もちろん他にもいろいろあるが、このガイドに当てはまるのはこれだ。）

1. まず、[i[`getaddrinfo()` function]]
   [`getaddrinfo()`](#structs) を使って、手で構造体を詰める代わりに、
   すべての `struct sockaddr` 情報を取得してみよう。これで IP バージョンに依存しないコードになり、後述のステップの多くが不要になる。

2. IP バージョンに関係するものをハードコードしている箇所があれば、ヘルパー関数にまとめてみよう。

3. `AF_INET` を `AF_INET6` に変更する。

4. `PF_INET` を `PF_INET6` に変更する。

5. `INADDR_ANY` への代入を `in6addr_any` への代入に変更する。少し違う：

   ```{.c}
   struct sockaddr_in sa;
   struct sockaddr_in6 sa6;
   
   sa.sin_addr.s_addr = INADDR_ANY;  // use my IPv4 address
   sa6.sin6_addr = in6addr_any; // use my IPv6 address
   ```

   また、`struct in6_addr` を宣言するときの初期化子として `IN6ADDR_ANY_INIT` も使える：

   ```{.c}
   struct in6_addr ia6 = IN6ADDR_ANY_INIT;
   ```

6. `struct sockaddr_in` の代わりに `struct sockaddr_in6` を使い、フィールド名には適宜「6」を付ける（上の [`struct`s](#structs) を参照）。`sin6_zero` フィールドはない。

7. `struct in_addr` の代わりに `struct in6_addr` を使い、フィールド名には適宜「6」を付ける（上の [`struct`s](#structs) を参照）。

8. `inet_aton()` や `inet_addr()` の代わりに `inet_pton()` を使う。

9. `inet_ntoa()` の代わりに `inet_ntop()` を使う。

10. `gethostbyname()` の代わりに、より優れた `getaddrinfo()` を使う。

11. `gethostbyaddr()` の代わりに、より優れた [i[`getnameinfo()`
    function]] `getnameinfo()` を使う（`gethostbyaddr()` は IPv6 でも動くが）。

12. `INADDR_BROADCAST` はもう使えない。代わりに IPv6 マルチキャストを使う。

できあがり！
