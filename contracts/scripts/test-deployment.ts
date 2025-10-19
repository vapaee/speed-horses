// contracts/scripts/test-deployment.ts
import { ethers } from 'hardhat';

// Este archivo debe implementar un script que haga ciertois testedos sobre los datos de los contratos on chain.
// Para saber donde están ubicados los contratos, deberá tomar la estructura del archivo src/environments/contracts.ts
// y usar la connfiguración que corresponda a la blockchain seleccionada por las variables de ambiente NETWORK_NAME y TELOS_EVM_MAINNET_RPC

// A partir de ahi debe consultar cada uno de los contratos inteligentes a ver si tienen bien seteados todos los controladores y referencias cruzadas que se setearon en el archivo contracts/scripts/deploy.ts

async function main(): Promise<void> {
    const signers = await ethers.getSigners();
    console.log('signers:', signers.map(s => s.address));
}
main();
