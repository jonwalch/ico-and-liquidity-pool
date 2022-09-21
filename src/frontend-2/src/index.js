import {BigNumber, ethers} from "ethers"
import RouterJSON from '../../../out/Router.sol/Router.json';
import IcoJSON from '../../../out/ICO.sol/ICO.json';
import PoolJSON from '../../../out/Pool.sol/Pool.json';

const provider = new ethers.providers.Web3Provider(window.ethereum)
const signer = provider.getSigner()

// const icoAddr = '0xf5059a5D33d5853360D16C683c16e67980206f36'
const icoAddr = '0x12d10B6Fc0AdfC9E5E395E881FBCa750b685f168'; // testnet
const icoContract = new ethers.Contract(icoAddr, IcoJSON.abi, provider);

// const poolAddr = '0x3fA4E6e03Fbd434A577387924aF39efd3b4b50F2';
const poolAddr = '0xb0ae8174198Ba36D8ED88642312A5738A22786B5'; //testnet
const poolContract = new ethers.Contract(poolAddr, PoolJSON.abi, provider);

// const routerAddr = '0x95401dc811bb5740090279Ba06cfA8fcF6113778'
const routerAddr = '0x8aE43802cA6b6346Cc01Fa12fe35B74568d07a31' // testnet
const routerContract = new ethers.Contract(routerAddr, RouterJSON.abi, provider);

async function getSPCBalance(){
  const receipt2 = await icoContract.spcLeft();
  const leftSpan = document.getElementById('ico_spc_left');
  leftSpan.textContent = ethers.utils.formatUnits(receipt2.toString(), 18);
}

async function connectToMetamask() {
  try {
    console.log("Signed in as", await signer.getAddress())
    await getSPCBalance();
  }
  catch(err) {
    console.log("Not signed in")
    await provider.send("eth_requestAccounts", [])
    await getSPCBalance();
  }
}

async function getSPCApproval() {
  const receipt = await icoContract.connect(signer)["approve(address,uint256)"](routerAddr, ethers.utils.parseEther("500000"));
  await receipt.wait()
}

async function getLPApproval() {
  const receipt = await poolContract.connect(signer).approve(routerAddr, ethers.utils.parseEther("5000000000000"));
  await receipt.wait()
}

function deadline() {
  return Date.now() + 120;
}

function minAmount(value) {
  return value * (1 - Number(slappage.slippy.value));
}

//
// ICO
//
ico_spc_buy.addEventListener('submit', async e => {
  e.preventDefault()
  const form = e.target
  const eth = ethers.utils.parseEther(form.eth.value)
  console.log("Buying", eth, "eth")

  await connectToMetamask()
  try {
    const receipt = await icoContract.connect(signer).contribute({value: eth, gasLimit: 100000});
    await receipt.wait()

    await getSPCBalance()
  } catch (error) {
    // console.log(Object.getOwnPropertyNames(error)); // ['stack', 'message', 'reason', 'code', 'transactionHash', 'transaction', 'receipt']

    let errorDescription;

    try {
      errorDescription = icoContract.interface.parseError(error.error.data.originalError.data).name;
    } catch (readError) {
      errorDescription = "Error name would go here if my ethers worked properly";
    }

    alert(errorDescription);
  }
})

//
// LP
//
let currentSpcToEthPrice = 5

async function getSpcToEthPrice() {
  try {
    const receipt = await routerContract.spcToEthPrice();
    currentSpcToEthPrice = Number(ethers.utils.formatUnits(receipt.toString(), 18));
  } catch (e) {
    currentSpcToEthPrice = 5;
    console.log(e);
  }
}

provider.on("block", async n => {
  console.log("New block", n)

  await getSPCBalance()
  await getSpcToEthPrice();

  console.log(currentSpcToEthPrice);

  // const r = await poolContract.etherReserve();
  // const rr = await poolContract.spcReserve();

})

ico_spc_withdraw.addEventListener('submit', async e => {
  e.preventDefault()
  const receipt = await icoContract.connect(signer).withdraw(
      await signer.getAddress(),
      {gasLimit: 100000}
  );
  await receipt.wait()
})

lp_deposit.eth.addEventListener('input', e => {
  lp_deposit.spc.value = +e.target.value * currentSpcToEthPrice
})

lp_deposit.spc.addEventListener('input', e => {
  lp_deposit.eth.value = +e.target.value / currentSpcToEthPrice
})

lp_deposit.addEventListener('submit', async e => {
  e.preventDefault()
  const form = e.target
  const eth = ethers.utils.parseEther(form.eth.value)
  const spc = ethers.utils.parseEther(form.spc.value)
  console.log("Depositing", eth, "eth and", spc, "spc")

  await getSPCApproval()

  try {
    const receipt = await routerContract.connect(signer).addLiquidity( //TODO: tweak args?
        spc, // amountDesiredSpc,
        minAmount(spc), // amountMinSpc,
        minAmount(eth), // amountMinEth,
        await signer.getAddress(),
        deadline(),
        {value: eth, gasLimit: 1000000}
    );
    await receipt.wait()
  } catch (err) {
      console.log(err);
  }
})

lp_withdraw.addEventListener('submit', async e => {
  e.preventDefault()
  console.log("Withdrawing 100% of LP")
  const totalSupply = await poolContract.totalSupply()
  const ethReserve = await poolContract.etherReserve()
  const spcReserve = await poolContract.spcReserve()

  // await connectToMetamask()
  await getLPApproval();
  const liquidity = await poolContract.connect(signer).balanceOf(await signer.getAddress());
  const amountSpc = liquidity.mul(spcReserve).div(totalSupply);
  const amountEth = liquidity.mul(ethReserve).div(totalSupply);
  const receipt = await routerContract.connect(signer).removeLiquidity(
      liquidity,
      minAmount(amountSpc), // amountMinSpc
      minAmount(amountEth), // amountMinEth
      await signer.getAddress(),
      deadline(),
      {gasLimit: 1000000}
);
  await receipt.wait();
})

//
// Swap
//
let swapIn = { type: 'eth', value: 0 }
let swapOut = { type: 'spc', value: 0 }
switcher.addEventListener('click', () => {
  [swapIn, swapOut] = [swapOut, swapIn]
  swap_in_label.innerText = swapIn.type.toUpperCase()
  swap.amount_in.value = swapIn.value
  updateSwapOutLabel()
})

swap.amount_in.addEventListener('input', updateSwapOutLabel)

function updateSwapOutLabel() {
  swapOut.value = swapIn.type === 'eth'
    ? +swap.amount_in.value * currentSpcToEthPrice
    : +swap.amount_in.value / currentSpcToEthPrice

  swap_out_label.innerText = `${swapOut.value} ${swapOut.type.toUpperCase()}`
}

swap.addEventListener('submit', async e => {
  e.preventDefault()
  const form = e.target
  const amountIn = ethers.utils.parseEther(form.amount_in.value)

  console.log("Swapping", amountIn, swapIn.type, "for", swapOut.type)

  await connectToMetamask();
  await getSpcToEthPrice();

  const spcOut = amountIn * currentSpcToEthPrice;
  if (swapIn.type == "eth") {
    const receipt = await routerContract.connect(signer).swapEthForSpc(
        minAmount(spcOut), // spcOutMin,
        await signer.getAddress(),
        deadline(),
        {value: amountIn, gasLimit: 1000000},
  );
    await receipt.wait();
  } else {
    const ethOut = amountIn / currentSpcToEthPrice;
    await getSPCApproval();
    const receipt = await routerContract.connect(signer).swapSpcForEth(
        amountIn, // spcIn
        minAmount(ethOut), // ethOutMin
        await signer.getAddress(),
        deadline(),
        {gasLimit: 1000000},
  );
    await receipt.wait();
  }
})
