const Web3 = require('web3');
const web3 = new Web3('http://localhost:8552'); // Ethereumノードに接続

const contractAddress = "0x3753fbe054560975d19cea828a244b1f39f379d4"; // コントラクトのアドレス
const contractABI = [{"inputs":[],"name":"sendCommand","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"pure","type":"function"}]; // コントラクトのABI

const contract = new web3.eth.Contract(contractABI, contractAddress);

// helloWorld関数を呼び出す
contract.methods.sendCommand().call()
  .then(result => {
    console.log(result); // Solidity関数の戻り値を表示
  })
  .catch(error => {
    console.error(error); // エラーがあれば表示
  });
