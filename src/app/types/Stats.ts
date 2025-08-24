export interface Stats {
    field: string;
    value: number;
    display: string;
};

export interface StatsPack {
    total: number;
    stats: Stats[];
}
