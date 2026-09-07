"use client";

import Image from "next/image";
import { useState } from "react";

export function TrainingExerciseMedia({ title, sourceVideoUrl, sourceImageUrl }: { title: string; sourceVideoUrl: string | null; sourceImageUrl: string | null }) {
  const [videoUnavailable, setVideoUnavailable] = useState(false);
  const [imageUnavailable, setImageUnavailable] = useState(false);
  const showVideo = Boolean(sourceVideoUrl) && !videoUnavailable;
  const showImage = !showVideo && Boolean(sourceImageUrl) && !imageUnavailable;

  if (!showVideo && !showImage) return null;

  return <figure className="bg-white">
    {showVideo ? <div className="bg-slate-950"><video controls playsInline preload="metadata" poster={sourceImageUrl ?? undefined} className="aspect-video w-full" onError={() => setVideoUnavailable(true)}><source src={sourceVideoUrl!} type="video/mp4" />Din webbläsare kan inte visa videon.</video></div> : null}
    {showImage ? <Image src={sourceImageUrl!} alt={`Övningsbild från källövningen ${title}`} width={900} height={506} className="aspect-[16/9] w-full object-contain" onError={() => setImageUnavailable(true)} /> : null}
    <figcaption className="px-4 py-2 text-xs text-slate-600">{showVideo ? "Film från källövningen hos Svensk Innebandy" : "Bild från källövningen hos Svensk Innebandy"}</figcaption>
  </figure>;
}
