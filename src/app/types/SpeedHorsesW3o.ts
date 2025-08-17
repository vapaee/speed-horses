
import {
    AntelopeTokensService,
    AntelopeResourcesService
} from "@vapaee/w3o-antelope";
import {
    EthereumTokensService
} from "@vapaee/w3o-ethereum";

export interface SpeedHorsesW3oServices {
    antelope: {
        tokens: AntelopeTokensService;
        resources: AntelopeResourcesService;
    };
    ethereum: {
        tokens: EthereumTokensService;
    };
    snapshot: () => any;
}
