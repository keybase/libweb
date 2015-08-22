##### Signed by https://keybase.io/max
```
-----BEGIN PGP SIGNATURE-----
Comment: GPGTools - http://gpgtools.org

iQEcBAABCAAGBQJV1/+5AAoJEJgKPw0B/gTf3BwIALmM0wAAQNhJeA00sQpiBERm
CStbALgIFOBhkeg01PB4Q2YhJ+TNdVQi0Rb5vyj2SIJCbdLqNfn/9Rsstg4kNYGQ
ZTDlV0mMsCAFSYf5va59Z8vlivtaZw9j/QRy5OzWC2hDFfNDwvVB8+sO9DaAdwLp
20Zud66wYrZxAiwbI5msClUkLY667Tc5AtH90PHljMDcH1GX8cEl31aBsir/qa4R
J3VGxA2gEZF9d2/Xlf5xnq3g1TRQBizweKk1SiExf8lep2EdA5KibWrc6LpywSJm
GAtnXAdn13LBEKPsKiRc9s87RiLrk3qH3eMfJR8E5M7HeVx3/xpTaLpPPwADsGY=
=iKQH
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
1197           Makefile          6b586bc9afcf444bc2c79a17d9c7801f855b00974c7020ef1f53cdc43ef4baab
106            README.md         d978c77b88d09bad0c92fba01e8b33b1722055d0bc364ac40b68cd08fd33c0ec
               lib/                                                                              
                 base/                                                                           
1746               config.js     e5da444f2b2d53609429df2024bb1c4269eb6de97e0dbec140f8de33f5f645d9
2519               request.js    18ff9fa3977d99051a25490d28a32f4440f6345d1f6126dc8bd0e1b597af386d
                 browser/                                                                        
121                index.js      59b0f98302da14e340e829ba95ba5e63d566680f08f07bb2c60e67f090b6e2d1
1724               request.js    8a02ec5bd0d6722e575292db09a4f8734dc7bed05f204aedb04f5fb44c8cf13f
                 hilevel/                                                                        
29513              account.js    d4cdebb7820958f7a5b28733d2e2f80775e4db068aeb61a714e325ce01305d5d
72                 config.js     2b2c11a80eae7c6c7b00c5569dc85942e934c193684dbbe36cdc8e9a0a8ebaa5
269                index.js      3fc222c31035594d0468593689c7f12851e84d81f1bcaa58dca36ff32de24ccf
                 node/                                                                           
121                index.js      59b0f98302da14e340e829ba95ba5e63d566680f08f07bb2c60e67f090b6e2d1
2623               request.js    373b0d585418414eda584335d509fa15db17f049c6cc00f357e466ad6346d89a
848            package.json      f7e8828815247c425b47795ba1dc53c1218dd79c5d9f12d1d3a287fbb2d617e1
               src/                                                                              
                 base/                                                                           
1086               config.iced   3b9aefddce1b2c9e3367ec68e4222d896f47d94276a2d53583280b801601b7e1
1402               request.iced  a7a99b84a0fd035f156ad5883211d3cf8617908a70446b99343a825f32769da7
                 browser/                                                                        
48                 index.iced    e19a549b30fcf6eb46bbae5f3d09ae8b78b82426a1f9839ab3a1392198df63ff
1049               request.iced  0ca4fc7b272a550a17ac31ec57cc4c5f717a9ecff244ed04c55462ff2d7b0f65
                 hilevel/                                                                        
7911               account.iced  62c5a5ad2cf835ccd2aded369f2cca8bff4209c5eacf096b2e5c9fb735537802
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