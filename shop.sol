pragma solidity ^0.4.21;
import "./SafeMath.sol";

contract Ownable { // Базовый контракт, обеспечивающий разграничение доступа
  address owner;
  mapping (address => bool) administrators;

  constructor() public {
    require(owner == 0);
    owner = msg.sender;
  }

  modifier onlyOwner() { // модификатор, Обеспечивающий возможность вызова функций только владельцем
    require(msg.sender == owner);
    _;
  }

  modifier onlyAdministrator() { // модификатор, Обеспечивающий возможность вызова функций только администратором
    require(administrators[msg.sender]);
    _;
  }
}

contract Shop is Ownable { // основной контракт
  using SafeMath for uint;  // инициализация библиотеки
  struct Trade { // струкутра, хранящая в себе сделку
    address sellerAddr;
    address buyerAddr;
    bytes32 dataHash;
    uint sum;
  }
  mapping (bytes32 => Trade) trades;
  uint commission = 10; // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
  uint commissionAmount; // размер доступных для вывода средств в wei

  // События вызываются для оповещения сервера
  event InitiateTrade(address sellerAddr, address buyerAddr, bytes32 dataHash, uint sum);
  event ResolveTrade(bytes32 tradeId, address sellerAddr, uint amount);
  event RejectTrade(bytes32 tradeId, address buyerAddr, uint amount);

  constructor(address[] _administrators) public {
    for(uint i = 0; i < _administrators.length; i++) { // инициализация администраторов
      administrators[_administrators[i]] = true;
    }
    administrators[owner] = true; // default: owner = admin
  }

  function initiateTrade( // функция для создания сделки
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
     require(msg.value == _sum); // Нужна ли возможность присылать больше eth? Разницу вернем
     // Собираем хэш для проверки подписи
     bytes32 messageHash = keccak256(abi.encodePacked(
       "\x19Ethereum Signed Message:\n32",
       keccak256(abi.encodePacked(
        _dataHash,
        bytes32(_sum),
        bytes32(_sellerAddr)
      ))));

     require(ecrecover(messageHash, uint8(_vSeller), _rSeller, _sSeller) == _sellerAddr); // проверяем корректность подписи продавца
     require(ecrecover(messageHash, uint8(_vBuyer), _rBuyer, _sBuyer) == msg.sender); // проверяем корректность подписи покупателя
     require(trades[_dataHash].dataHash == 0); // проверяем, что сделки еще не существует
     Trade memory trade = Trade(_sellerAddr, msg.sender, _dataHash, _sum); // инициализация сделки
     trades[_dataHash] = trade;
     emit InitiateTrade(_sellerAddr, msg.sender, _dataHash, _sum); // оповещение эвентом
  }

  function resolveTrade(bytes32 tradeId) public onlyAdministrator { // при вызове функции деньги перечисляются продавцу
    Trade memory trade = trades[tradeId];
    // вычисление комиссии сервиса
    uint _amountCommission = trade.sum;
    _amountCommission = _amountCommission.div(10000).mul(commission); // 10000, т.к. комиссия хранится не в процентах (100% * 100)
    uint amount = trade.sum.sub(_amountCommission);
    address _sellerAddr = trade.sellerAddr;
    commissionAmount = commissionAmount.add(_amountCommission);

    // трансфер денег продавцу и удаление сделки
    delete(trades[tradeId]);
    _sellerAddr.transfer(amount);
    emit ResolveTrade(tradeId, _sellerAddr, amount);
  }

  function rejectTrade(bytes32 tradeId) public onlyAdministrator { // при вызове функции деньги перечисляются покупателю, сделка неуспешна
    Trade memory trade = trades[tradeId];
    uint amount = trade.sum;
    address _buyerAddr = trade.buyerAddr;
    // перечисляем деньги обратно покупателю и удаляем сделку
    delete(trades[tradeId]);
    _buyerAddr.transfer(amount);
    emit RejectTrade(tradeId, _buyerAddr, amount);
  }

  function withdrawCommission(address destination) public onlyOwner { // Вывод собранной комиссии на переданный адрес
    commissionAmount = 0;
    destination.transfer(commissionAmount);
  }

  function setCommission(uint _commission) onlyOwner public { // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
    require(_commission > 0);
    commission = _commission;
  }

  function getCommissionAmount() public onlyOwner view returns(uint) { // доступные для вывода средства
    return commissionAmount;
  }

  function addAdministrator(address _administrator) public onlyOwner { // добавление администратора
    require(!administrators[_administrator]);
    administrators[_administrator] = true;
  }

  function deleteAdminitstrator(address _administrator) public onlyOwner { // удаление администратора
    require(administrators[_administrator]);
    administrators[_administrator] = false;
  }

  function isAdministrator(address addr) public onlyOwner view returns(bool) { // проверка на администратора
    return administrators[addr];
  }
}
    