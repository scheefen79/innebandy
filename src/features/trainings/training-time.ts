const stockholmDate=new Intl.DateTimeFormat("sv-SE",{timeZone:"Europe/Stockholm",weekday:"long",day:"numeric",month:"long"});
const stockholmTime=new Intl.DateTimeFormat("sv-SE",{timeZone:"Europe/Stockholm",hour:"2-digit",minute:"2-digit"});
export function formatTrainingTime(startsAt:string,endsAt:string){return `${stockholmDate.format(new Date(startsAt))} · ${stockholmTime.format(new Date(startsAt))}–${stockholmTime.format(new Date(endsAt))}`;}
