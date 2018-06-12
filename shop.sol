pragma solidity ^0.4.24;
import "./SafeMath.sol";

contract Ownable {
  address owner;
  mapping (address => bool) administrators;

  constructor() public {
    require(owner == 0);
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  modifier onlyAdministrator() {
    require(administrators[msg.sender]);
    _;
  }
}

contract Shop is Ownable{
  using SafeMath for uint;
  struct Trade {
    address sellerAddr;
    address buyerAddr;
    bytes32 dataHash;
    uint sum;
  }
  mapping (bytes32 => Trade) trades;
  uint commission = 10; // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
  uint commissionAmount; // размер доступных для вывода средств в wei

  event InitiateTrade(address sellerAddr, address buyerAddr, bytes32 dataHash, uint sum);
  event ResolveTrade(bytes32 tradeId, address sellerAddr, uint amount);
  event RejectTrade(bytes32 tradeId, address buyerAddr, uint amount);

  constructor(address[] _administrators) public{
    for(uint i = 0; i < _administrators.length; i++) {
      administrators[_administrators[i]] = true;
    }
    administrators[owner] = true;
  }

  function initiateTrade(
    address _sellerAddr,
    uint _vSeller,
    bytes32 _rSeller,
    bytes32 _sSeller,
    uint _vBuyer,
    bytes32 _rBuyer,
    bytes32 _sBuyer,
    bytes32 _dataHash,
    uint _sum
   ) payable public {
     require(msg.value == _sum);
     require(ecrecover(_dataHash, uint8(_vSeller), _rSeller, _sSeller) == _sellerAddr); // проверяем корректность подписи продавца
     require(ecrecover(_dataHash, uint8(_vBuyer), _rBuyer, _sBuyer) == msg.sender); // проверяем корректность подписи покупателя
     require(trades[_dataHash].dataHash == 0);
     Trade memory trade = Trade(_sellerAddr, msg.sender, _dataHash, _sum);
     trades[_dataHash] = trade;
     emit InitiateTrade(_sellerAddr, msg.sender, _dataHash, _sum);
  }

  function resolveTrade(bytes32 tradeId) public onlyAdministrator {
    Trade memory trade = trades[tradeId];
    uint _amountCommission = trade.sum;
    _amountCommission = _amountCommission.div(10000).mul(commission); // 10000, т.к. комиссия хранится не в процентах (100% * 100)
    uint amount = trade.sum.sub(_amountCommission);
    address _sellerAddr = trade.sellerAddr;
    commissionAmount = commissionAmount.add(_amountCommission);
    _sellerAddr.transfer(amount);
    delete(trades[tradeId]);
    emit ResolveTrade(tradeId, _sellerAddr, amount);
  }

  function rejectTrade(bytes32 tradeId) public onlyAdministrator {
    Trade memory trade = trades[tradeId];
    uint amount = trade.sum;
    address _buyerAddr = trade.buyerAddr;
    _buyerAddr.transfer(amount);
    delete(trades[tradeId]);
    emit RejectTrade(tradeId, _buyerAddr, amount);
  }

  function withdrawCommission(address destination) public onlyOwner {
    destination.transfer(commissionAmount);
    commissionAmount = 0;
  }

  function setCommission(uint _commission) onlyOwner public { // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
    require(_commission > 0);
    commission = _commission;
  }

  function getCommissionAmount() public onlyOwner view returns(uint){
    return commissionAmount;
  }

  function addAdministrator(address _administrator) public onlyOwner {
    require(!administrators[_administrator]);
    administrators[_administrator] = true;
  }

  function deleteAdminitstrator(address _administrator) public onlyOwner {
    require(administrators[_administrator]);
    administrators[_administrator] = false;
  }
}
