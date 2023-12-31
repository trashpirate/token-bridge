/**
 *         BUY, HOLD, EARN, BURN!
 *         Telegram: https://t.me/buyholdearn
 *         Website: http://buyholdearn.com
 *         X: https://twitter.com/buyholdearn
 */

// SPDX-License-Identifier: MIT

/**
 * This contract is derived from the ERC20.sol by openzeppelin and the
 *  reflection token contract by CoinTools. The contract removes liquidity and
 *  burn fee and only redistributes tokens to holders.
 */

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract HoldEarn is Context, IERC20, IERC20Metadata, Ownable {
    uint256 private constant MAX = ~uint256(0);
    uint256 private _rTotalSupply; // total supply in r-space
    uint256 private immutable i_tTotalSupply; // total supply in t-space
    string private _name;
    string private _symbol;
    address[] private _excludedFromReward;

    uint256 public taxFee = 200; // 200 => 2%
    uint256 public totalFees;

    mapping(address => uint256) private _rBalances; // balances in r-space
    mapping(address => uint256) private _tBalances; // balances in t-space
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromReward;

    event SetFee(uint256 value);

    constructor(address initialOwner) Ownable(msg.sender) {
        _name = "HOLD";
        _symbol = "EARN";
        i_tTotalSupply = 1_000_000_000 * 10 ** decimals();
        excludeFromFee(initialOwner);
        excludeFromFee(address(this));
        _mint(initialOwner, i_tTotalSupply);
        transferOwnership(initialOwner);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return i_tTotalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        if (isExcludedFromReward[account]) return _tBalances[account];
        uint256 rate = _getRate();
        return _rBalances[account] / rate;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address account, address spender) public view virtual returns (uint256) {
        return _allowances[account][spender];
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowance(msg.sender, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = allowance(msg.sender, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function setFee(uint256 newTxFee) public onlyOwner {
        taxFee = newTxFee;
        emit SetFee(taxFee);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!isExcludedFromReward[account], "Address already excluded");
        require(_excludedFromReward.length < 100, "Excluded list is too long");

        if (_rBalances[account] > 0) {
            uint256 rate = _getRate();
            _tBalances[account] = _rBalances[account] / rate;
        }
        isExcludedFromReward[account] = true;
        _excludedFromReward.push(account);
    }

    function includeInReward(address account) public onlyOwner {
        require(isExcludedFromReward[account], "Account is already included");
        uint256 nExcluded = _excludedFromReward.length;
        for (uint256 i = 0; i < nExcluded; i++) {
            if (_excludedFromReward[i] == account) {
                _excludedFromReward[i] = _excludedFromReward[_excludedFromReward.length - 1];
                _tBalances[account] = 0;
                isExcludedFromReward[account] = false;
                _excludedFromReward.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) public onlyOwner {
        isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        isExcludedFromFee[account] = false;
    }

    function withdrawTokens(address tokenAddress, address receiverAddress) external onlyOwner returns (bool success) {
        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 amount = tokenContract.balanceOf(address(this));
        return tokenContract.transfer(receiverAddress, amount);
    }

    function _getRate() private view returns (uint256) {
        uint256 rSupply = _rTotalSupply;
        uint256 tSupply = i_tTotalSupply;

        uint256 nExcluded = _excludedFromReward.length;
        for (uint256 i = 0; i < nExcluded; i++) {
            rSupply = rSupply - _rBalances[_excludedFromReward[i]];
            tSupply = tSupply - _tBalances[_excludedFromReward[i]];
        }
        if (rSupply < _rTotalSupply / i_tTotalSupply) {
            rSupply = _rTotalSupply;
            tSupply = i_tTotalSupply;
        }
        // rSupply always > tSupply (no precision loss)
        uint256 rate = rSupply / tSupply;
        return rate;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        // require(amount > 0, "Transfer amount must be greater than zero");

        uint256 _taxFee;
        if (isExcludedFromFee[from] || isExcludedFromFee[to]) {
            _taxFee = 0;
        } else {
            _taxFee = taxFee;
        }

        // calc t-values
        uint256 tAmount = amount;
        uint256 tTxFee = (tAmount * _taxFee) / 10000;
        uint256 tTransferAmount = tAmount - tTxFee;

        // calc r-values
        uint256 rate = _getRate();
        uint256 rTxFee = tTxFee * rate;
        uint256 rAmount = tAmount * rate;
        uint256 rTransferAmount = rAmount - rTxFee;

        // check balances
        uint256 rFromBalance = _rBalances[from];
        uint256 tFromBalance = _tBalances[from];

        if (isExcludedFromReward[from]) {
            require(tFromBalance >= tAmount, "ERC20: transfer amount exceeds balance");
        } else {
            require(rFromBalance >= rAmount, "ERC20: transfer amount exceeds balance");
        }

        // Overflow not possible: the sum of all balances is capped by
        // rTotalSupply and tTotalSupply, and the sum is preserved by
        // decrementing then incrementing.
        unchecked {
            // udpate balances in r-space
            _rBalances[from] = rFromBalance - rAmount;
            _rBalances[to] += rTransferAmount;

            // update balances in t-space
            if (isExcludedFromReward[from] && isExcludedFromReward[to]) {
                _tBalances[from] = tFromBalance - tAmount;
                _tBalances[to] += tTransferAmount;
            } else if (isExcludedFromReward[from] && !isExcludedFromReward[to]) {
                // could technically underflow but tAmount is a
                // function of rAmount and _rTotalSupply is mapped to i_tTotalSupply
                _tBalances[from] = tFromBalance - tAmount;
            } else if (!isExcludedFromReward[from] && isExcludedFromReward[to]) {
                // could technically overflow but tAmount is a
                // function of rAmount and _rTotalSupply is mapped to i_tTotalSupply
                _tBalances[to] += tTransferAmount;
            }

            // reflect fee
            // can never go below zero because rTxFee percentage of
            // current _rTotalSupply
            _rTotalSupply = _rTotalSupply - rTxFee;
            totalFees += tTxFee;
        }

        emit Transfer(from, to, tTransferAmount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _rTotalSupply += (MAX - (MAX % amount));
        unchecked {
            _rBalances[account] += _rTotalSupply;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(address account, address spender, uint256 amount) internal {
        require(account != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[account][spender] = amount;
        emit Approval(account, spender, amount);
    }

    function _spendAllowance(address account, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(account, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(account, spender, currentAllowance - amount);
            }
        }
    }
}
