import generateTsAbis from "./generateTsAbis";

async function main() {
    console.log("Running generateTsAbis...");
    // The function mostly uses fs and ignores the HRE argument, so passing an empty object
    await generateTsAbis({} as any);
    console.log("Done.");
}

main().catch(console.error);
