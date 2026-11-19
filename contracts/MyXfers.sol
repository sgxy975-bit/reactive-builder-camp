// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/// @title MyXfers - 监控 Sepolia 上的 ERC-20 转账
/// @notice 基于官方 omni 分支 Xfers 示例修改：
///         1. 单笔金额 >= MIN_AMOUNT 才计入成交量（细筛）
///         2. 每个事件都计入次数上限，到达上限自动退订，防止测试币被耗光
contract MyXfers is AbstractReactive {
    event Turnover(address indexed token, uint256 indexed volume);

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    // keccak256("Transfer(address,address,uint256)")
    uint256 private constant ERC20_TRANSFER_TOPIC_0 =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    address public immutable OWNER;
    uint256 public immutable MIN_AMOUNT;

    uint256 public remaining;       // 还能处理多少个事件
    uint256 public seenCount;       // 一共收到多少个事件
    uint256 public bigCount;        // 其中大额转账有多少个
    uint256 public lastTxHash;
    uint256 public lastReactBlock;
    mapping(address => uint256) public turnovers;

    constructor(uint256 limit_, uint256 minAmount_) payable {
        OWNER = msg.sender;
        remaining = limit_;
        MIN_AMOUNT = minAmount_;
        _sub();
    }

    function react(LogRecord calldata log_) external onlySystem {
        // 粗筛之后的细筛：不关心的事件一律 return，不用 revert
        if (remaining == 0) return;

        // 每个事件都计入上限，到 0 就退订
        remaining -= 1;
        if (remaining == 0) {
            _unsub();
        }

        seenCount += 1;
        lastTxHash = log_.txHash;
        lastReactBlock = block.number;

        // ERC-20 的 Transfer 有 3 个 topic（opCode 3）；NFT 的 Transfer 有 4 个，跳过
        if (log_.opCode != 3) return;
        if (log_.data.length < 32) return;

        uint256 amount = abi.decode(log_.data, (uint256));
        if (amount < MIN_AMOUNT) return;

        bigCount += 1;
        turnovers[log_.contractAddress] += amount;
        emit Turnover(log_.contractAddress, amount);
    }

    function _sub() internal {
        SYSTEM.subscribe(
            SEPOLIA_CHAIN_ID,
            address(0),                 // 任意代币合约
            ERC20_TRANSFER_TOPIC_0,     // 只要 Transfer 事件
            REACTIVE_IGNORE,            // 转出方不限
            REACTIVE_IGNORE,            // 收款方不限
            REACTIVE_IGNORE
        );
    }

    function _unsub() internal {
        SYSTEM.unsubscribe(
            SEPOLIA_CHAIN_ID,
            address(0),
            ERC20_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
}
