# D4 跨链回调三步走

## 完整链路

```
① 源链 Sepolia：CampOrigin.ping(500) 发出 Ping 事件
      ↓  Reactive 按订阅匹配
② Lasna：CampReactive.react() 判断 500 ≥ 阈值 100，请求回调
      ↓  Callback Proxy 投递
③ 目标链 Sepolia：CampCallback.onEvent() 被调用，发出 Handled 事件
```

使用官方模板 [ethpanda-org/reactive-builder-camp](https://github.com/ethpanda-org/reactive-builder-camp) 的 `starter/`，源链和目标链都是 Ethereum Sepolia。

## 合约地址

| 合约 | 链 | 地址 |
|---|---|---|
| CampOrigin | Sepolia | `0x3E1225991dcFEB38c720246b080B70fb8e9cdcC6` |
| CampReactive | Lasna | [0xf66eE294b8E17208b0B062A3f3d5905Da145FaBD](https://lasna.reactscan.net/address/0xf66eE294b8E17208b0B062A3f3d5905Da145FaBD) |
| CampCallback | Sepolia | `0xA8F43b92F1b7a3Fd279bAD530595459CF3412297` |

Callback Proxy（Sepolia）：`0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`，已对照官方文档 Origins & Destinations 页面核实。

## 三笔交易

1. **源链事件：** [0x971e5ee3...d4cddecb](https://sepolia.etherscan.io/tx/0x971e5ee35422cddb2e12b3680bdb71cffc4084bfdc9c859eda0096e5d4cddecb)（区块 12169461）
2. **Reactive react()：** [0x06d2d503...adaeced2](https://lasna.reactscan.net/tx/0x06d2d503712217160d412520bf108ef5a845ed0de2739016fd7ded29adaeced2)
3. **目标链回调：** [0xb394f3c1...476aa36a](https://sepolia.etherscan.io/tx/0xb394f3c122320d1b153b1f42a56bd1477c53430f2f39bbd305dea226476aa36a)（区块 12169462）

**源链事件到回调落地只差 1 个区块。**

## verify.sh 核验结果

- Reactive：`lastTxHash` 和源链 Ping 交易一致；`remaining` 从 5 变成 4
- 回调合约：`count = 1`，`lastValue = 500`
- 回调合约 balance 从 0.02 变成 0.0199999937 ETH：目标链上执行回调的 gas 从这里扣，所以回调合约也要充值

## 失败实验

用自己的钱包直接调用回调函数：

```bash
cast send $CALLBACK_ADDR "onEvent(address,uint256,uint256,uint256)" \
  0x0000000000000000000000000000000000000000 11155111 1 999 \
  --rpc-url https://sepolia.gateway.tenderly.co --private-key $PRIVATE_KEY
```

结果：

```
NotAuthorized(0xd1a3d69F33668A5fF1D825Bc4A07Bc2Cdd920A99, 0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4)
```

**为什么被拒绝：** 回调合约设置了 `onlyServiceProvider` 校验，只允许 Callback Proxy（0xAa14…D23b4）调用；我用自己的钱包（0xd1a3…0A99）直接调用，调用者不是 Proxy，所以被拒绝。这样可以防止任何人伪造回调、随意触发目标链上的操作。

**回调合约的两道门：**
1. `onlyServiceProvider`：调用者必须是 Callback Proxy
2. `onlyCallbackSender`：第一个参数必须是我自己的 Reactive 合约地址（由 Proxy 自动填入），所以 `onEvent` 的第一个参数是 `address`

## 遇到的问题

部署回调合约时报错 `block not found`：模板默认的公共 RPC 节点没同步到最新区块。换成另一个公共节点 `https://sepolia.gateway.tenderly.co` 后成功。**不是代码问题，是节点问题。**

第一次跑 `verify.sh` 时 `count = 0`：回调还在路上，等一会儿再跑就变成 1 了。可以在 Reactscan 的 Callbacks 标签页看到状态 `INCLUDED ON DESTINATION`。
