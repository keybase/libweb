##### Signed by https://keybase.io/max
```
-----BEGIN PGP SIGNATURE-----
Comment: GPGTools - https://gpgtools.org

iQEcBAABCgAGBQJV2yfkAAoJEJgKPw0B/gTfP1kH/0YYDxNk8OZRuQlC+Pej7Px5
LB26kIHmfPVSfRf+ul7mJTMYFf+WDgpPwx8gvBWJdr5zi8pPujD/kZWFMl7nkRld
DigSC34KgSHDytFyVzppo8U7cND44x6U/ymqt4xEVVJ5SD0zYKUZWjGW7ZTMs/cd
vUPxGkfwl4P4Qdl+pdSmLeTlsaQOEuEEI5qNBObwAepYpRLAd8fmXhBbgdxD9yoM
KLnCMdC1GvyERN8M6DRcgx2gBXe7WWkPx8sCmS+H2K+zhQC6HJVPwan9ZTzsG7XE
6wAFTo817jCgQ4sG8fC3FyRJ99xlCl3twb74E0/w5huABviRYBdYwav6at6sLik=
=LACr
-----END PGP SIGNATURE-----

```

<!-- END SIGNATURES -->

### Begin signed statement 

#### Expect

```
size   exec  file                contents                                                        
             ./                                                                                  
539            .gitignore        e20a434fd5bad9e0cf4f650681f730e5e2d432228e29d4ff2e668919a01ab977
86             CHANGELOG.md      4df44ac1fd348c1d4198040a7d12d70cc0922e6193d6a308d001170f22086a01
1475           LICENSE           5133df37c9842a4baea5e923bb14a6f2222f74cb90892f6a44ed7ef5f486d71e
1217           Makefile          b59b0df8d7defa41abda332cc3b0e7c0dfb2c9a61ec712214cafc232b515696f
106            README.md         d978c77b88d09bad0c92fba01e8b33b1722055d0bc364ac40b68cd08fd33c0ec
               lib/                                                                              
                 base/                                                                           
1746               config.js     e5da444f2b2d53609429df2024bb1c4269eb6de97e0dbec140f8de33f5f645d9
2519               request.js    18ff9fa3977d99051a25490d28a32f4440f6345d1f6126dc8bd0e1b597af386d
1010               util.js       99abbd4b82e059d0808bbc780522220f661536e86e69a25cd944a84f667dd9c2
                 browser/                                                                        
121                index.js      59b0f98302da14e340e829ba95ba5e63d566680f08f07bb2c60e67f090b6e2d1
1724               request.js    8a02ec5bd0d6722e575292db09a4f8734dc7bed05f204aedb04f5fb44c8cf13f
                 hilevel/                                                                        
52486              account.js    2ce7bf34f84407354480ecf8c71e909d3929d097d4f7d88781c84641f6b9ea5e
72                 config.js     2b2c11a80eae7c6c7b00c5569dc85942e934c193684dbbe36cdc8e9a0a8ebaa5
269                index.js      3fc222c31035594d0468593689c7f12851e84d81f1bcaa58dca36ff32de24ccf
                 node/                                                                           
121                index.js      59b0f98302da14e340e829ba95ba5e63d566680f08f07bb2c60e67f090b6e2d1
2623               request.js    373b0d585418414eda584335d509fa15db17f049c6cc00f357e466ad6346d89a
876            package.json      24812db790a2220779fac175cccaefedc11ba82750c088deea10ba02153f5d4f
               src/                                                                              
                 base/                                                                           
1086               config.iced   3b9aefddce1b2c9e3367ec68e4222d896f47d94276a2d53583280b801601b7e1
1402               request.iced  a7a99b84a0fd035f156ad5883211d3cf8617908a70446b99343a825f32769da7
513                util.iced     b2e472565dcdd56c394e63dea4430fe42ba81de26e6031df11bd12ab3b21750b
                 browser/                                                                        
48                 index.iced    e19a549b30fcf6eb46bbae5f3d09ae8b78b82426a1f9839ab3a1392198df63ff
1049               request.iced  0ca4fc7b272a550a17ac31ec57cc4c5f717a9ecff244ed04c55462ff2d7b0f65
                 hilevel/                                                                        
12736              account.iced  3e1d16cf8a1b85f2afd52fb30e01b4927356c808aef4108a0a631fbd2c2acc3a
188                index.iced    4de577245e33d59fce634857b2ac6600e91377b932a775a6867b7b8237f83346
                 node/                                                                           
48                 index.iced    e19a549b30fcf6eb46bbae5f3d09ae8b78b82426a1f9839ab3a1392198df63ff
923                request.iced  aa601ee36ca0024bdeb3f09f262bceb1152a73e75c798db95a3d010c1e6cfe09
```

#### Ignore

```
/SIGNED.md
```

#### Presets

```
git      # ignore .git and anything as described by .gitignore files
dropbox  # ignore .dropbox-cache and other Dropbox-related files    
kb       # ignore anything as described by .kbignore files          
```

<!-- summarize version = 0.0.9 -->

### End signed statement

<hr>

#### Notes

With keybase you can sign any directory's contents, whether it's a git repo,
source code distribution, or a personal documents folder. It aims to replace the drudgery of:

  1. comparing a zipped file to a detached statement
  2. downloading a public key
  3. confirming it is in fact the author's by reviewing public statements they've made, using it

All in one simple command:

```bash
keybase dir verify
```

There are lots of options, including assertions for automating your checks.

For more info, check out https://keybase.io/docs/command_line/code_signing