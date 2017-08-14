pragma solidity ^0.4.0;

contract owned {
    
    address public owner;
    
    function owned() {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }
    
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData);
}

contract MegaToken is owned {
    /* This creates an array with all balances */
    mapping (address => uint256 ) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    
    string public standard = "Token 0.1";
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    uint256 public sellPrice;
    uint256 public buyPrice;
    
    uint minBalanceForAccounts;
    
    // this generates public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /* Initializes contract with initial supply tokens to the creator of the contract */
    function MegaToken(uint256 initialSupply, string tokenName, uint8 decimalUnits, string tokenSymbol, address centralMinter) {
        balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
        totalSupply = initialSupply;                        // 
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
        decimals = decimalUnits;                            // Amount of decimals for display purpose
        if (centralMinter != 0) owner = centralMinter;
    }
    
    /* Send coins */
    function transfer(address _to, uint256 _value) {
        require(approvedAccount[msg.sender]);
        
        /*Check if sender has balance and for overflows */
        require(balanceOf[msg.sender] > _value || balanceOf[_to] + _value > balanceOf[_to]);
        
        /*Add and substract balances*/
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        
        /* Notify anyone listening that this transfer took place */
        Transfer(msg.sender, _to, _value);
        
        if (_to.balance < minBalanceForAccounts) {
            _to.send((minBalanceForAccounts - _to.balance) / sellPrice);
        }
    }
    
    // allow another contract to spent some tokens in your behalf
    function approve(address _spender, uint256 _value) returns(bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }
    
    // approve and then communicate the approved contract in a single tx
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns(bool success){
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }
    
    // a contract attempts to get the coins
    function transferFrom(address _from, address _to, uint256 _value) returns(bool success) {
        require(balanceOf[_from] > _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);
        require(_value < allowance[_from][msg.sender]);
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }
    
    /* add more tokens*/
    function mintToken(address target, uint256 mintedAmount) onlyOwner {
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, owner, mintedAmount);
        Transfer(owner, target, mintedAmount);
    }
    
    /* Freeze accounts */
    mapping (address => bool) public approvedAccount;
    event FrozenFunds(address target, bool frozen);
    
    function approveAccount(address target, bool freeze) onlyOwner {
        approvedAccount[target] = freeze;
        FrozenFunds(target, !freeze);
    }
    
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
    function buy() payable returns(uint amount) {
        amount = msg.value;                 // calculates the amount
        require(balanceOf[this] > amount);  // check if it has enough to sell
        balanceOf[msg.sender] += amount;    // adds the amount to buyes balance 
        balanceOf[this] -= amount;          // substracts amount from the seller's amount
        Transfer(this, msg.sender, amount); // execute an event reflecting the change
        return amount;                      // ends function and return
    }
    
    function sell(uint amount) returns(uint revenue) {
        require(balanceOf[msg.sender] > amount);        // check if sender has enough to sell
        balanceOf[this] += amount;                      // add's amount to the owners balance
        balanceOf[msg.sender] -= amount;                // substracts the amount from seller's balance
        revenue = amount * sellPrice;
        if (!msg.sender.send(revenue)) {                // sends ether to the seller: Important!
            throw;                                      // to do this last ot prevent recursion attacks
        } else {                            
            Transfer(msg.sender, this, amount);         // executes an event reflection on the change
            return revenue;                             // ends function and returns
        }
    }
    
    function setMinBalance(uint minBalanceInFinney) onlyOwner {
        minBalanceForAccounts = minBalanceInFinney * 1 finney;
    }
    
    // this unnamed function is called whenever someone tries to send ether to it. 
    function () {
        throw; // prevents accidental sending of ether
    }
}





