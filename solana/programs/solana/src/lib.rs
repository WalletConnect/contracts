use anchor_lang::prelude::*;

declare_id!("3o24BJPniXvoYR2YU4vTuJkuk6Th6b7G2TPQPykP4qci");

#[program]
pub mod solana {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
