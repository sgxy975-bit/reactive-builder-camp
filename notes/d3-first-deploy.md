# D3 第一次部署：监控 Sepolia 上的代币转账

## 提交内容

- **合约地址：** [0xc2822c08dADF186A6aE253B7Fd9358636b444554](https://lasna.reactscan.net/address/0xc2822c08dADF186A6aE253B7Fd9358636b444554)
- **一笔 react() 交易：** [0xd771298d...52266bd8](https://lasna.reactscan.net/tx/0xd771298d8720a02899ebc6f64e75695e724066691eda249fcf2e351352266bd8)
- **订阅过滤条件：** 订阅 Sepolia（chainId 11155111）上所有 ERC-20 合约的 `Transfer` 事件（合约地址用 `address(0)` 通配，topic1–3 用 `REACTIVE_IGNORE`）；在 `react()` 里只记录单笔 ≥ 1 个代币（1e18）的转账，每个事件都计入 20 次上限，到达后自动退订。

合约代码：[contracts/MyXfers.sol](../contracts/MyXfers.sol)

## 我改了什么

基于官方 omni 分支的 Xfers 示例，改了两处：

1. **加了金额阈值**：单笔 ≥ `MIN_AMOUNT` 才计入成交量，小额转账直接 `return`（细筛）
2. **每个事件都计入次数上限**：不管金额大小，收到一个就减一次。否则小额转账会一直进来、一直扣费，测试币可能被耗光

## 部署命令

```bash
forge build
forge create src/MyXfers.sol:MyXfers \
  --rpc-url https://lasna-rpc.rnk.dev/ \
  --private-key $PRIVATE_KEY \
  --value 0.5ether \
  --broadcast \
  --constructor-args 20 1000000000000000000
```

- `--value 0.5ether`：部署时充值 0.5 lREACT
- `--constructor-args 20 1e18`：最多处理 20 个事件；单笔至少 1 个代币（代币一般 18 位小数）
- 私钥放在 `.env` 里，不写进命令，也不上传 GitHub

## 链上结果

| 项目 | 结果 | 说明 |
|---|---|---|
| Reactive Executions | 20 笔，全部 SUCCESS | react() 被调用了 20 次，正好是上限 |
| Subscriptions | 0 | 次数用完，自动退订成功 |
| Balance | 0.5 → 0.2292 lREACT | 20 次花了约 0.27，平均每次约 0.0135 |
| Debt | 0 | 没有欠费 |

## 我学到的

- **订阅太宽 = 烧钱快**：订阅"所有代币"，20 次几秒钟就用完了，全部发生在同一个区块里。订阅越精准，触发越少
- **次数上限很重要**：没有上限的话，0.5 lREACT 很快会被耗光
- **合约只负责"听"**：那些转账是 Sepolia 上其他人转的，我的合约只记账，自己没有转任何钱
- **Foundry 是工具，不是平台**：`forge build` 编译、`forge test` 在本地模拟测试、`forge create` 部署到链上。合约部署后住在 Lasna 链上，电脑关机也照样运行
