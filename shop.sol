pragma solidity ^0.4.21;

contract Ownable {
  address owner;
  mapping (address => bool) administrators;

  function Ownable() {
    require(owner == 0);
    msg.sender = owner;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
}

contract Shop is Ownable{
  struct Trade {
    address sellerAddr;
    address buyerAddr;
    bytes32 dataHash;
    uint sum;
  }
  mapping (bytes32 => trade) trades;
  uint commission = 10; // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
  uint commissionAmount; // размер доступных для вывода средств в wei

  event InitiateTrade(address sellerAddr, address buyerAddr, bytes32 dataHash, uint sum);

  function Shop(address[] _administrators) {
    for(uint i = 0; i < _administrators.length(); i++) {
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
     require(trades[_dataHash] == 0);
     Trade trade = new Trade(_sellerAddr, msg.sender, _dataHash, _sum);
     trades[_dataHash] = trade;
     InitiateTrade(_sellerAddr, msg.sender, _dataHash, _sum);
  }

  function resolveTrade(bytes32 tradeId) public{

  }

  function rejectTrade(bytes32 tradeId) public{

  }

  function withdrawCommission(address destination) public onlyOwner {
    destination.transfer(commissionAmount);
    commissionAmount = 0;
  }

  function setCommission(uint _commission) onlyOwner public { // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
    require(_commission > 0);
    commission = _commission;
  }

  function getCommissionAmount() public onlyOwner {
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
